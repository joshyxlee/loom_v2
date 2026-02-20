#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from datetime import date, datetime
from html import escape

TIME_SENSITIVE_KEYWORDS = [
    "現任", "目前", "現在", "最新", "本季", "今年", "最近", "近期", "排名", "世界第",
]
ROLE_KEYWORDS = [
    "總統", "首相", "總理", "主席", "CEO", "總裁", "教練", "隊長",
]

NBA_KEYWORDS = ["NBA", "球隊", "季後賽", "選秀", "交易"]
NEWS_KEYWORDS = ["最新", "最近", "近期"]


def is_time_sensitive(prompt: str) -> bool:
    text = prompt or ""
    # avoid false positives like "表現在"
    if "現在" in text:
        cleaned = text.replace("表現在", "")
    else:
        cleaned = text
    if any(k in cleaned for k in TIME_SENSITIVE_KEYWORDS):
        return True
    if any(k in cleaned for k in ROLE_KEYWORDS):
        return True
    return False


def classify_tags(prompt: str, subject: str) -> list:
    tags = ["time-sensitive"]
    if subject == "nba" or "NBA" in (prompt or ""):
        tags.append("nba")
    if any(k in (prompt or "") for k in ROLE_KEYWORDS):
        tags.append("people-role")
    if any(k in (prompt or "") for k in NEWS_KEYWORDS):
        tags.append("news")
    return tags


def audit(repo_root: Path):
    assets_dir = repo_root / "assets" / "questions"
    reports_dir = repo_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    today = date.today()
    stale = []

    for path in sorted(assets_dir.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for q in data:
            prompt = q.get("prompt") or q.get("question") or ""
            subject = q.get("subject", "")
            if not is_time_sensitive(prompt):
                continue

            reasons = []
            missing = []
            for field in ("asOf", "expiryDays", "sources"):
                if field not in q:
                    missing.append(field)
            if missing:
                reasons.append("missing: " + ", ".join(missing))
            else:
                try:
                    as_of = datetime.strptime(q["asOf"], "%Y-%m-%d").date()
                    expiry = int(q["expiryDays"])
                    if (today - as_of).days > expiry:
                        reasons.append("expired")
                except Exception:
                    reasons.append("invalid asOf/expiryDays")

            if reasons:
                stale.append({
                    "pack": path.name,
                    "id": q.get("id"),
                    "prompt": prompt,
                    "asOf": q.get("asOf"),
                    "expiryDays": q.get("expiryDays"),
                    "tags": q.get("tags", classify_tags(prompt, subject)),
                    "sources": q.get("sources"),
                    "reason": "; ".join(reasons),
                })

    json_path = reports_dir / "stale_questions.json"
    html_path = reports_dir / "stale_questions.html"
    json_path.write_text(json.dumps(stale, ensure_ascii=False, indent=2), encoding="utf-8")

    rows = []
    for item in stale:
        rows.append(
            "<tr>"
            f"<td>{escape(str(item.get('pack','')))}</td>"
            f"<td>{escape(str(item.get('id','')))}</td>"
            f"<td>{escape(str(item.get('prompt','')))}</td>"
            f"<td>{escape(str(item.get('asOf','')))}</td>"
            f"<td>{escape(str(item.get('expiryDays','')))}</td>"
            f"<td>{escape(', '.join(item.get('tags') or []))}</td>"
            f"<td>{escape(', '.join(item.get('sources') or []))}</td>"
            f"<td>{escape(str(item.get('reason','')))}</td>"
            "</tr>"
        )

    html = f"""
<!doctype html>
<html lang=\"zh-Hant\">
<head>
  <meta charset=\"utf-8\" />
  <title>Stale Questions</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; vertical-align: top; }}
    th {{ background: #f3f3f3; }}
  </style>
</head>
<body>
  <h1>Stale Questions</h1>
  <p>Total: {len(stale)}</p>
  <table>
    <thead>
      <tr>
        <th>Pack</th>
        <th>ID</th>
        <th>Prompt</th>
        <th>asOf</th>
        <th>expiryDays</th>
        <th>tags</th>
        <th>sources</th>
        <th>reason</th>
      </tr>
    </thead>
    <tbody>
      {''.join(rows)}
    </tbody>
  </table>
</body>
</html>
"""
    html_path.write_text(html, encoding="utf-8")

    print(f"Stale questions: {len(stale)}")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    try:
        audit(repo_root)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
