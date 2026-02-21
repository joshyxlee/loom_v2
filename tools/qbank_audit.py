#!/usr/bin/env python3
"""
Usage:
  python3 tools/qbank_audit.py

Outputs:
  reports/qbank_audit.html
  reports/qbank_audit.md
  reports/qbank_audit.json
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
    "核心答案是",
    "因為對應條件最完整",
    "邏輯上最順",
    "容易被選成",
    "忽略題目設定差異",
]

EXAMPLE_HINTS = ["例如", "比如", "像"]
CONTRAST_HINTS = ["相比", "對比", "與", "更", "不同"]
MECHANISM_HINTS = ["因", "因此", "所以", "因為", "導致", "造成"]
WRONG_OPTION_HINTS = ["誤解", "錯", "容易把", "把"]


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


def has_example(explanation: str) -> bool:
    return any(h in explanation for h in EXAMPLE_HINTS)


def has_contrast(explanation: str) -> bool:
    return any(h in explanation for h in CONTRAST_HINTS)


def has_mechanism(explanation: str) -> bool:
    return any(h in explanation for h in MECHANISM_HINTS)


def has_wrong_option(explanation: str) -> bool:
    return any(h in explanation for h in WRONG_OPTION_HINTS)


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
    depth_counts = defaultdict(int)
    length_by_pack = defaultdict(list)

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
            example_ok = has_example(explanation)
            contrast_ok = has_contrast(explanation)
            mechanism_ok = has_mechanism(explanation)
            wrong_ok = has_wrong_option(explanation)
            length = len(explanation)
            length_by_pack[path.name].append(length)

            if example_ok:
                depth_counts["example"] += 1
            if contrast_ok:
                depth_counts["contrast"] += 1
            if mechanism_ok:
                depth_counts["mechanism"] += 1
            if wrong_ok:
                depth_counts["wrong_option"] += 1

            all_rows.append(
                {
                    "pack": path.name,
                    "id": qid,
                    "question": prompt,
                    "options": options,
                    "answer": f"{answer_index} - {answer_text}",
                    "explanation": explanation,
                    "banned_phrase_hit": "Y: " + ", ".join(banned_hits) if banned_hits else "N",
                    "has_example": "Y" if example_ok else "N",
                    "has_contrast": "Y" if contrast_ok else "N",
                    "has_mechanism": "Y" if mechanism_ok else "N",
                    "has_wrong_option": "Y" if wrong_ok else "N",
                    "explanation_length": length,
                }
            )

    # Duplicate checks
    id_counts = Counter(id_list)
    duplicate_ids = sorted([i for i, c in id_counts.items() if i and c > 1])

    prompt_counts = Counter([p for p in prompt_list if p])
    duplicate_prompts = sorted([p for p, c in prompt_counts.items() if c > 1])

    avg_length_by_pack = {k: round(sum(v) / len(v), 1) for k, v in length_by_pack.items()}

    summary = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_packs": len(question_files),
        "total_questions": len(all_rows),
        "duplicate_ids": duplicate_ids,
        "duplicate_prompts": duplicate_prompts,
        "depth_counts": dict(depth_counts),
        "avg_length_by_pack": avg_length_by_pack,
    }

    json_path = reports_dir / "qbank_audit.json"
    json_path.write_text(json.dumps({"summary": summary, "items": all_rows}, ensure_ascii=False, indent=2), encoding="utf-8")

    # HTML report
    rows_html = []
    for row in all_rows:
        options_html = "<ol>" + "".join(f"<li>{escape(str(opt))}</li>" for opt in row["options"]) + "</ol>"
        rows_html.append(
            "<tr class='row' data-pack='{pack}'>"
            "<td>{pack}</td>"
            "<td>{qid}</td>"
            "<td>{question}</td>"
            "<td>{options}</td>"
            "<td>{answer}</td>"
            "<td>{explanation}</td>"
            "<td>{banned}</td>"
            "<td>{example}</td>"
            "<td>{contrast}</td>"
            "<td>{mechanism}</td>"
            "<td>{wrong}</td>"
            "<td>{length}</td>"
            "</tr>".format(
                pack=escape(str(row["pack"])),
                qid=escape(str(row["id"])),
                question=escape(str(row["question"])),
                options=options_html,
                answer=escape(str(row["answer"])),
                explanation=escape(str(row["explanation"])),
                banned=escape(str(row["banned_phrase_hit"])),
                example=escape(str(row["has_example"])),
                contrast=escape(str(row["has_contrast"])),
                mechanism=escape(str(row["has_mechanism"])),
                wrong=escape(str(row["has_wrong_option"])),
                length=escape(str(row["explanation_length"])),
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
  </style>
</head>
<body>
  <h1>QBank Audit Report</h1>
  <div class=\"controls\">
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
        <th>HasExample</th>
        <th>HasContrast</th>
        <th>HasMechanism</th>
        <th>HasWrongOption</th>
        <th>Length</th>
      </tr>
    </thead>
    <tbody>
      {''.join(rows_html)}
    </tbody>
  </table>
  <script>
    const searchBox = document.getElementById('searchBox');
    const packFilter = document.getElementById('packFilter');
    function applyFilters() {{
      const term = searchBox.value.toLowerCase();
      const pack = packFilter.value;
      document.querySelectorAll('tbody tr').forEach(row => {{
        const text = row.innerText.toLowerCase();
        const rowPack = row.getAttribute('data-pack');
        const matchTerm = text.includes(term);
        const matchPack = !pack || rowPack === pack;
        row.style.display = (matchTerm && matchPack) ? '' : 'none';
      }});
    }}
    searchBox.addEventListener('input', applyFilters);
    packFilter.addEventListener('change', applyFilters);
  </script>
</body>
</html>
"""

    html_path = reports_dir / "qbank_audit.html"
    html_path.write_text(html, encoding="utf-8")

    # Markdown report
    by_pack = defaultdict(list)
    for row in all_rows:
        by_pack[row["pack"]].append(row)

    md_lines = []
    md_lines.append("# QBank Audit 摘要")
    md_lines.append("")
    md_lines.append(f"- 產生時間：{summary['generated_at']}")
    md_lines.append(f"- 題庫數：{summary['total_packs']}")
    md_lines.append(f"- 題目數：{summary['total_questions']}")
    md_lines.append("")
    md_lines.append("## 深度檢查統計")
    md_lines.append("")
    md_lines.append(f"- 例子：{summary['depth_counts'].get('example',0)}")
    md_lines.append(f"- 對比：{summary['depth_counts'].get('contrast',0)}")
    md_lines.append(f"- 機制：{summary['depth_counts'].get('mechanism',0)}")
    md_lines.append(f"- 錯選項：{summary['depth_counts'].get('wrong_option',0)}")
    md_lines.append("")
    md_lines.append("## 各科平均字數")
    for pack, avg in summary['avg_length_by_pack'].items():
        md_lines.append(f"- {pack}: {avg}")

    md_lines.append("")
    md_lines.append("## 各科完整題目")
    for pack in sorted(by_pack.keys()):
        md_lines.append("")
        md_lines.append(f"### {pack}")
        for row in by_pack[pack]:
            md_lines.append("")
            md_lines.append(f"**{row['id']}**")
            md_lines.append(f"- Q: {row['question']}")
            md_lines.append(f"- Options: {', '.join([str(o) for o in row['options']])}")
            md_lines.append(f"- A: {row['answer']}")
            md_lines.append(f"- E: {row['explanation']}")

    md_path = reports_dir / "qbank_audit.md"
    md_path.write_text("\n".join(md_lines), encoding="utf-8")

    if duplicate_ids:
        print(f"ERROR: Duplicate IDs found: {duplicate_ids}", file=sys.stderr)
        sys.exit(1)

    print("Done. Next: python3 tools/qbank_audit.py && git add reports/qbank_audit.html reports/qbank_audit.md reports/qbank_audit.json && git commit -m \"audit: update qbank reports\" && git push")


if __name__ == "__main__":
    main()
