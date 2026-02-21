#!/usr/bin/env python3
"""
Usage:
  python3 tools/qbank_audit.py

Outputs:
  reports/qbank_audit.html
  reports/qbank_audit.md
  reports/qbank_audit_summary.json

Quick run+commit:
  python3 tools/qbank_audit.py && git add reports/qbank_audit.html reports/qbank_audit.md reports/qbank_audit_summary.json && git commit -m "audit: update qbank reports" && git push
"""
import json
import sys
import re
from pathlib import Path
from html import escape
from datetime import datetime
from collections import Counter, defaultdict

BANNED_PHRASES = [
    "容易被表面誤導",
    "這種題",
    "這類題",
    "重點不是直覺",
    "看不見的物理機制",
    "真正成本與長期影響",
]

HOLLOW_HINTS = ["核心定義", "重點在於", "幫助判斷", "容易誤導", "選項", "答案是"]
CAUSAL_HINTS = ["因", "因此", "所以", "因為", "導致", "造成"]
NOUN_HINTS = ["國", "洲", "河", "海", "山", "城", "市", "年", "公里", "公尺", "分鐘", "分", "人"]


def load_questions(path: Path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, list):
        raise ValueError(f"Invalid JSON structure in {path}: expected a list")
    return data


def normalize_prompt(text: str) -> str:
    return "".join((text or "").strip().lower().split())


def detect_banned(explanation: str):
    hits = []
    for phrase in BANNED_PHRASES:
        if re.search(phrase, explanation, flags=re.IGNORECASE):
            hits.append(phrase)
    return hits


def is_hollow(explanation: str) -> bool:
    if len(explanation.strip()) < 20:
        return True
    if any(h in explanation for h in HOLLOW_HINTS):
        return True
    has_number = bool(re.search(r"\d", explanation))
    has_causal = any(h in explanation for h in CAUSAL_HINTS)
    has_noun = any(h in explanation for h in NOUN_HINTS)
    return not (has_number or has_causal or has_noun)


def severity_score(banned_hits, hollow, length):
    score = 0
    if banned_hits:
        score += 5
    if hollow:
        score += 3
    if length < 20:
        score += 2
    return score


def main():
    repo_root = Path(__file__).resolve().parents[1]
    assets_dir = repo_root / "assets" / "questions"
    reports_dir = repo_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    question_files = sorted(assets_dir.glob("*.json"))
    if not question_files:
        print(f"ERROR: No question files found under {assets_dir}", file=sys.stderr)
        sys.exit(1)

    all_rows = []
    id_list = []
    prompt_list = []
    banned_by_pack = defaultdict(int)
    hollow_by_pack = defaultdict(int)

    for path in question_files:
        data = load_questions(path)
        for q in data:
            qid = q.get("id")
            prompt = q.get("prompt") or q.get("question") or ""
            options = q.get("options") or []
            answer_index = q.get("answerIndex")
            explanation = q.get("explanation") or ""
            answer_text = ""
            if isinstance(answer_index, int) and 0 <= answer_index < len(options):
                answer_text = str(options[answer_index])

            id_list.append(qid)
            prompt_list.append(normalize_prompt(prompt))

            banned_hits = detect_banned(explanation)
            hollow = is_hollow(explanation)
            length = len(explanation)
            score = severity_score(banned_hits, hollow, length)

            if banned_hits:
                banned_by_pack[path.name] += 1
            if hollow:
                hollow_by_pack[path.name] += 1

            all_rows.append(
                {
                    "pack": path.name,
                    "id": qid,
                    "question": prompt,
                    "options": options,
                    "answer": f"{answer_index} - {answer_text}",
                    "explanation": explanation,
                    "banned_phrase_hit": "Y: " + ", ".join(banned_hits) if banned_hits else "N",
                    "explanation_length": length,
                    "hollow": "Y" if hollow else "N",
                    "severity": score,
                }
            )

    # Duplicate checks
    id_counts = Counter(id_list)
    duplicate_ids = sorted([i for i, c in id_counts.items() if i and c > 1])

    prompt_counts = Counter([p for p in prompt_list if p])
    duplicate_prompts = sorted([p for p, c in prompt_counts.items() if c > 1])

    issues_count = sum(1 for row in all_rows if row["banned_phrase_hit"] != "N" or row["hollow"] == "Y") + len(duplicate_ids)

    summary = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_packs": len(question_files),
        "total_questions": len(all_rows),
        "issues_count": issues_count,
        "duplicate_ids": duplicate_ids,
        "duplicate_prompts": duplicate_prompts,
        "banned_by_pack": dict(banned_by_pack),
        "hollow_by_pack": dict(hollow_by_pack),
    }

    summary_path = reports_dir / "qbank_audit_summary.json"
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    # HTML report
    rows_html = []
    for row in all_rows:
        issue_class = "issue" if row["banned_phrase_hit"] != "N" or row["hollow"] == "Y" else ""
        options_html = "<ol>" + "".join(f"<li>{escape(str(opt))}</li>" for opt in row["options"]) + "</ol>"
        rows_html.append(
            "<tr class='row {cls}' data-pack='{pack}'>"
            "<td>{pack}</td>"
            "<td>{qid}</td>"
            "<td>{question}</td>"
            "<td>{options}</td>"
            "<td>{answer}</td>"
            "<td>{explanation}</td>"
            "<td>{banned}</td>"
            "<td>{hollow}</td>"
            "<td>{length}</td>"
            "<td>{severity}</td>"
            "</tr>".format(
                cls=issue_class,
                pack=escape(str(row["pack"])),
                qid=escape(str(row["id"])),
                question=escape(str(row["question"])),
                options=options_html,
                answer=escape(str(row["answer"])),
                explanation=escape(str(row["explanation"])),
                banned=escape(str(row["banned_phrase_hit"])),
                hollow=escape(str(row["hollow"])),
                length=escape(str(row["explanation_length"])),
                severity=escape(str(row["severity"])),
            )
        )

    packs = sorted({row["pack"] for row in all_rows})
    pack_options = "".join(f"<option value='{escape(p)}'>{escape(p)}</option>" for p in packs)

    html = f"""
<!doctype html>
<html lang=\"zh-Hant\">
<head>
  <meta charset=\"utf-8\" />
  <title>QBank Audit Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .controls {{ margin-bottom: 16px; display: flex; gap: 12px; flex-wrap: wrap; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; vertical-align: top; }}
    th {{ background: #f3f3f3; position: sticky; top: 0; }}
    tr.issue {{ background: #ffe8e8; }}
  </style>
</head>
<body>
  <h1>QBank Audit Report</h1>
  <div class=\"controls\">
    <label><input type=\"checkbox\" id=\"failOnly\" /> 只顯示 FAIL</label>
    <select id=\"packFilter\">
      <option value=\"\">全部 pack</option>
      {pack_options}
    </select>
    <input id=\"searchBox\" type=\"text\" placeholder=\"Search keyword\" />
  </div>
  <table>
    <thead>
      <tr>
        <th>Pack</th>
        <th>ID</th>
        <th>Question</th>
        <th>Options</th>
        <th>Answer</th>
        <th>Explanation</th>
        <th>BannedPhraseHit</th>
        <th>Hollow</th>
        <th>Length</th>
        <th>Severity</th>
      </tr>
    </thead>
    <tbody>
      {''.join(rows_html)}
    </tbody>
  </table>
  <script>
    const searchBox = document.getElementById('searchBox');
    const packFilter = document.getElementById('packFilter');
    const failOnly = document.getElementById('failOnly');

    function applyFilters() {{
      const term = searchBox.value.toLowerCase();
      const pack = packFilter.value;
      const onlyFail = failOnly.checked;
      document.querySelectorAll('tbody tr').forEach(row => {{
        const text = row.innerText.toLowerCase();
        const rowPack = row.getAttribute('data-pack');
        const isFail = row.classList.contains('issue');
        const matchTerm = text.includes(term);
        const matchPack = !pack || rowPack === pack;
        const matchFail = !onlyFail || isFail;
        row.style.display = (matchTerm && matchPack && matchFail) ? '' : 'none';
      }});
    }}

    searchBox.addEventListener('input', applyFilters);
    packFilter.addEventListener('change', applyFilters);
    failOnly.addEventListener('change', applyFilters);
  </script>
</body>
</html>
"""

    html_path = reports_dir / "qbank_audit.html"
    html_path.write_text(html, encoding="utf-8")

    # Markdown report (mobile friendly)
    by_pack = defaultdict(list)
    for row in all_rows:
        by_pack[row["pack"]].append(row)

    md_lines = []
    md_lines.append("# QBank Audit 摘要")
    md_lines.append("")
    md_lines.append("- HTML：./qbank_audit.html")
    md_lines.append("")
    md_lines.append(f"- 產生時間：{summary['generated_at']}")
    md_lines.append(f"- 題庫數：{summary['total_packs']}")
    md_lines.append(f"- 題目數：{summary['total_questions']}")
    md_lines.append(f"- 問題數（模板命中或空洞）：{summary['issues_count']}")
    md_lines.append("")
    md_lines.append("## 各題庫問題統計")
    md_lines.append("")
    for pack in sorted(by_pack.keys()):
        banned = banned_by_pack.get(pack, 0)
        hollow = hollow_by_pack.get(pack, 0)
        md_lines.append(f"- {pack}: 模板句命中 {banned}｜空洞解釋 {hollow}")

    # Top 20 worst
    md_lines.append("")
    md_lines.append("## 最需要重寫的 20 題")
    worst = sorted(all_rows, key=lambda r: r["severity"], reverse=True)[:20]
    for row in worst:
        md_lines.append(f"- {row['id']}｜{row['question']}（Severity {row['severity']}）")

    # Sample 30
    md_lines.append("")
    md_lines.append("## 抽樣 30 題")
    sample = sorted(all_rows, key=lambda r: r["id"] or "")[:30]
    for row in sample:
        md_lines.append("")
        md_lines.append(f"**{row['id']}**")
        md_lines.append(f"- Q: {row['question']}")
        md_lines.append(f"- A: {row['answer']}")
        md_lines.append(f"- E: {row['explanation']}")

    md_path = reports_dir / "qbank_audit.md"
    md_path.write_text("\n".join(md_lines), encoding="utf-8")

    if duplicate_ids:
        print(f"ERROR: Duplicate IDs found: {duplicate_ids}", file=sys.stderr)
        sys.exit(1)

    print("Done. Next: python3 tools/qbank_audit.py && git add reports/qbank_audit.html reports/qbank_audit.md reports/qbank_audit_summary.json && git commit -m \"audit: update qbank reports\" && git push")


if __name__ == "__main__":
    main()
