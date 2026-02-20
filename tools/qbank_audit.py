#!/usr/bin/env python3
import json
import sys
import os
import re
from pathlib import Path
from html import escape
from difflib import SequenceMatcher

FORBIDDEN_PHRASES = [
    "這種題",
    "這類題",
    "容易被表面誤導",
    "名氣帶偏",
    "直覺就對",
    "猜題",
    "套路",
    "尺度感",
    "關鍵在於",  # special handling: only flag when used alone
]

GENERIC_TONE_PHRASES = [
    "這題很簡單",
    "其實很簡單",
    "只要記住",
    "記住",
    "不要被表面迷惑",
    "不要只看表面",
    "請仔細閱讀題目",
    "別被直覺騙",
    "別被表面迷惑",
]

PUNCT_RE = re.compile(r"[\s\u3000\t\n\r\f\v\.,!?，。！？、；;:\-—()（）\[\]{}<>《》\"'“”‘’]+")


def normalize_text(text: str) -> str:
    text = text.strip().lower()
    text = PUNCT_RE.sub("", text)
    return text


def has_concrete_tokens(explanation: str) -> bool:
    if re.search(r"\d", explanation):
        return True
    if re.search(r"[A-Za-z]", explanation):
        return True
    if re.search(r"[「『《](.+?)[」』》]", explanation):
        return True
    return False


def is_hollow_explanation(explanation: str) -> bool:
    if len(explanation.strip()) < 40:
        return True
    normalized = normalize_text(explanation)
    for phrase in GENERIC_TONE_PHRASES:
        if normalized == normalize_text(phrase):
            return True
    return False


def forbidden_hits(explanation: str):
    hits = []
    for phrase in FORBIDDEN_PHRASES:
        if phrase == "關鍵在於":
            if explanation.strip() == phrase:
                hits.append(phrase)
        else:
            if phrase in explanation:
                hits.append(phrase)
    return hits


def load_questions(path: Path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, list):
        raise ValueError(f"Invalid JSON structure in {path}: expected a list")
    for idx, item in enumerate(data):
        if not isinstance(item, dict):
            raise ValueError(f"Invalid item in {path} at index {idx}: expected object")
        required = ["id", "options", "answerIndex", "explanation"]
        missing = [k for k in required if k not in item]
        if missing:
            raise ValueError(f"Missing keys in {path} at index {idx}: {', '.join(missing)}")
        if "prompt" not in item and "question" not in item:
            raise ValueError(f"Missing prompt/question in {path} at index {idx}")
    return data


def build_reports(repo_root: Path):
    assets_dir = repo_root / "assets" / "questions"
    reports_dir = repo_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    question_files = sorted(assets_dir.glob("*.json"))
    if not question_files:
        raise ValueError(f"No question files found under {assets_dir}")

    all_questions = []
    per_file = {}

    for path in question_files:
        questions = load_questions(path)
        per_file[path.name] = questions
        for q in questions:
            q_copy = dict(q)
            q_copy["_pack"] = path.name
            q_copy["_prompt"] = q.get("prompt") or q.get("question") or ""
            all_questions.append(q_copy)

    # Duplicate detection
    normalized_prompts = [normalize_text(q.get("_prompt", "")) for q in all_questions]
    duplicates_map = {i: set() for i in range(len(all_questions))}
    exact_groups = {}
    for i, norm in enumerate(normalized_prompts):
        exact_groups.setdefault(norm, []).append(i)
    for indices in exact_groups.values():
        if len(indices) > 1:
            for i in indices:
                duplicates_map[i].update([j for j in indices if j != i])

    # Similarity detection (pairwise)
    for i in range(len(all_questions)):
        for j in range(i + 1, len(all_questions)):
            if normalized_prompts[i] == normalized_prompts[j]:
                continue
            ratio = SequenceMatcher(None, normalized_prompts[i], normalized_prompts[j]).ratio()
            if ratio >= 0.92:
                duplicates_map[i].add(j)
                duplicates_map[j].add(i)

    # Flagging
    flagged_items = []
    summary = {}
    total_duplicate_pairs = 0

    for idx, q in enumerate(all_questions):
        reasons = []
        explanation = q.get("explanation") or ""

        hits = forbidden_hits(explanation)
        if hits:
            reasons.append(f"forbidden phrase: {', '.join(hits)}")

        if is_hollow_explanation(explanation):
            reasons.append("hollow explanation")

        if duplicates_map[idx]:
            reasons.append("duplicate prompt")
            total_duplicate_pairs += len(duplicates_map[idx])

        if not has_concrete_tokens(explanation):
            reasons.append("low info explanation")

        q["_flags"] = reasons
        if reasons:
            flagged_items.append(q)

    # Summary per file
    for pack_name, questions in per_file.items():
        pack_questions = [q for q in all_questions if q["_pack"] == pack_name]
        total = len(pack_questions)
        flagged = sum(1 for q in pack_questions if q.get("_flags"))
        flag_rate = round((flagged / total) if total else 0, 4)
        duplicates_count = sum(1 for q in pack_questions if q.get("_flags") and "duplicate prompt" in q["_flags"])
        forbidden_count = sum(1 for q in pack_questions if q.get("_flags") and any(r.startswith("forbidden phrase") for r in q["_flags"]))
        hollow_count = sum(1 for q in pack_questions if q.get("_flags") and "hollow explanation" in q["_flags"])
        summary[pack_name] = {
            "total_questions": total,
            "flagged": flagged,
            "flag_rate": flag_rate,
            "duplicates_count": duplicates_count,
            "forbidden_hits_count": forbidden_count,
            "hollow_count": hollow_count,
        }

    write_full_report(reports_dir / "questions_full.html", per_file)
    write_red_flags_report(reports_dir / "red_flags.html", flagged_items)
    (reports_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    # Console summary
    sorted_packs = sorted(summary.items(), key=lambda x: x[1]["flag_rate"], reverse=True)
    print("Top 5 packs by flag rate:")
    for name, stats in sorted_packs[:5]:
        print(f"- {name}: {stats['flag_rate']:.2%} ({stats['flagged']}/{stats['total_questions']})")
    print(f"Total duplicate pairs across all packs: {total_duplicate_pairs // 2}")

    return flagged_items


def write_full_report(path: Path, per_file):
    pack_links = []
    pack_sections = []

    for pack_name, questions in per_file.items():
        anchor = f"pack-{pack_name.replace('.', '-') }"
        pack_links.append(f"<a href='#{anchor}'>{escape(pack_name)}</a>")
        rows = []
        for q in questions:
            answer_index = q.get("answerIndex")
            options = q.get("options") or []
            answer_text = ""
            if isinstance(answer_index, int) and 0 <= answer_index < len(options):
                answer_text = options[answer_index]
            else:
                answer_text = "(invalid answerIndex)"
            options_html = "".join(f"<li>{escape(str(opt))}</li>" for opt in options)
            difficulty = q.get("difficulty", "")
            rows.append(
                "<div class='question'>"
                f"<div class='qid'><strong>ID:</strong> {escape(str(q.get('id','')))}</div>"
                f"<div class='prompt'><strong>Prompt:</strong> {escape(str(q.get('prompt') or q.get('question') or ''))}</div>"
                f"<div class='options'><strong>Options:</strong><ol>{options_html}</ol></div>"
                f"<div class='answer'><strong>Answer:</strong> {answer_index} - {escape(str(answer_text))}</div>"
                f"<div class='explanation'><strong>Explanation:</strong> {escape(str(q.get('explanation','')))}</div>"
                f"<div class='difficulty'><strong>Difficulty:</strong> {escape(str(difficulty))}</div>"
                "</div>"
            )
        pack_sections.append(
            f"<section id='{anchor}'>"
            f"<h2>{escape(pack_name)}</h2>"
            + "\n".join(rows)
            + "</section>"
        )

    html = f"""
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <title>Question Bank Full Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .search {{ margin-bottom: 16px; }}
    .pack-links a {{ margin-right: 12px; }}
    .question {{ border: 1px solid #ddd; padding: 12px; margin: 12px 0; border-radius: 6px; }}
    .question .prompt {{ margin-top: 6px; }}
    .question ol {{ margin: 6px 0 0 18px; }}
  </style>
</head>
<body>
  <h1>Question Bank Full Report</h1>
  <div class="search">
    <label for="searchBox"><strong>Search:</strong></label>
    <input id="searchBox" type="text" placeholder="Type to filter" />
  </div>
  <div class="pack-links">{' | '.join(pack_links)}</div>
  {''.join(pack_sections)}
  <script>
    const searchBox = document.getElementById('searchBox');
    searchBox.addEventListener('input', () => {{
      const term = searchBox.value.toLowerCase();
      document.querySelectorAll('.question').forEach(q => {{
        const text = q.innerText.toLowerCase();
        q.style.display = text.includes(term) ? '' : 'none';
      }});
    }});
  </script>
</body>
</html>
"""
    path.write_text(html, encoding="utf-8")


def write_red_flags_report(path: Path, flagged_items):
    rows = []
    for q in flagged_items:
        reasons = "; ".join(q.get("_flags", []))
        rows.append(
            "<div class='question'>"
            f"<div class='qid'><strong>ID:</strong> {escape(str(q.get('id','')))} ({escape(q.get('_pack',''))})</div>"
            f"<div class='prompt'><strong>Prompt:</strong> {escape(str(q.get('_prompt','')))}</div>"
            f"<div class='reasons'><strong>Flags:</strong> {escape(reasons)}</div>"
            f"<div class='explanation'><strong>Explanation:</strong> {escape(str(q.get('explanation','')))}</div>"
            "</div>"
        )

    html = f"""
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <title>Question Bank Red Flags</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .question {{ border: 1px solid #e08; padding: 12px; margin: 12px 0; border-radius: 6px; background: #fff5f7; }}
  </style>
</head>
<body>
  <h1>Question Bank Red Flags</h1>
  <p>Total flagged: {len(flagged_items)}</p>
  {''.join(rows)}
</body>
</html>
"""
    path.write_text(html, encoding="utf-8")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    try:
        flagged_items = build_reports(repo_root)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
