#!/usr/bin/env python3
"""
Usage:
  python3 tools/qbank_audit.py

Outputs:
  reports/qbank_audit.md
  reports/qbank_full_by_pack.md
  reports/qbank_audit.json
"""
import json
import sys
import re
from pathlib import Path
from datetime import datetime
from collections import Counter, defaultdict

BANNED_PHRASES = [
    "這題在考",
    "看到關鍵詞",
    "方向落在",
    "符合題意",
    "常見誤解",
    "容易選成",
    "因此選",
    "排除",
]

EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF]")

EXAMPLE_HINTS = ["例如", "比如", "像"]
CONTRAST_HINTS = ["比", "相比", "對比"]
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


def cjk_len(text: str) -> int:
    return len(re.sub(r"\s+", "", text or ""))


def sentence_count(text: str) -> int:
    return len(re.findall(r"[。！？]", text or ""))


def emoji_count(text: str) -> int:
    return len(EMOJI_RE.findall(text or ""))


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
    length_by_pack = defaultdict(list)
    depth_counts = defaultdict(int)
    banned_total = 0
    length_fail = 0
    sentence_fail = 0
    emoji_fail = 0

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
            if banned_hits:
                banned_total += 1

            length = cjk_len(explanation)
            s_count = sentence_count(explanation)
            e_count = emoji_count(explanation)

            if length < 22 or length > 60:
                length_fail += 1
            if s_count < 1 or s_count > 3:
                sentence_fail += 1
            if e_count > 2:
                emoji_fail += 1

            example_ok = has_example(explanation)
            contrast_ok = has_contrast(explanation)
            mechanism_ok = has_mechanism(explanation)
            wrong_ok = has_wrong_option(explanation)

            if example_ok:
                depth_counts["example"] += 1
            if contrast_ok:
                depth_counts["contrast"] += 1
            if mechanism_ok:
                depth_counts["mechanism"] += 1
            if wrong_ok:
                depth_counts["wrong_option"] += 1

            length_by_pack[path.name].append(length)

            all_rows.append(
                {
                    "pack": path.name,
                    "id": qid,
                    "question": prompt,
                    "options": options,
                    "answer": f"{answer_index} - {answer_text}",
                    "explanation": explanation,
                    "banned_phrase_hit": "Y: " + ", ".join(banned_hits) if banned_hits else "N",
                    "length": length,
                    "sentence_count": s_count,
                    "emoji_count": e_count,
                    "has_example": "Y" if example_ok else "N",
                    "has_contrast": "Y" if contrast_ok else "N",
                    "has_mechanism": "Y" if mechanism_ok else "N",
                    "has_wrong_option": "Y" if wrong_ok else "N",
                }
            )

    avg_length_by_pack = {k: round(sum(v) / len(v), 1) for k, v in length_by_pack.items()}

    summary = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_questions": len(all_rows),
        "banned_phrase_hits": banned_total,
        "char_length_violations": length_fail,
        "sentence_count_violations": sentence_fail,
        "emoji_gt2": emoji_fail,
        "avg_length_by_pack": avg_length_by_pack,
        "depth_counts": dict(depth_counts),
    }

    json_path = reports_dir / "qbank_audit.json"
    json_path.write_text(json.dumps({"summary": summary, "items": all_rows}, ensure_ascii=False, indent=2), encoding="utf-8")

    # qbank_audit.md
    md_lines = []
    md_lines.append("# QBank Audit 摘要")
    md_lines.append("")
    md_lines.append(f"- 產生時間：{summary['generated_at']}")
    md_lines.append(f"- 題目數：{summary['total_questions']}")
    md_lines.append(f"- banned phrase 命中：{summary['banned_phrase_hits']}")
    md_lines.append(f"- 字數範圍違規：{summary['char_length_violations']}")
    md_lines.append(f"- 句數違規：{summary['sentence_count_violations']}")
    md_lines.append(f"- emoji >2：{summary['emoji_gt2']}")
    md_lines.append("")
    md_lines.append("## 各科平均字數")
    for pack, avg in summary['avg_length_by_pack'].items():
        md_lines.append(f"- {pack}: {avg}")

    md_lines.append("")
    md_lines.append("## 深度檢查統計")
    md_lines.append(f"- 例子：{summary['depth_counts'].get('example',0)}")
    md_lines.append(f"- 對比：{summary['depth_counts'].get('contrast',0)}")
    md_lines.append(f"- 機制：{summary['depth_counts'].get('mechanism',0)}")
    md_lines.append(f"- 錯選項：{summary['depth_counts'].get('wrong_option',0)}")

    # Top 30 (by length violations first)
    md_lines.append("")
    md_lines.append("## Top 30 需重寫")
    candidates = sorted(all_rows, key=lambda r: (r['length'] < 22 or r['length'] > 60, r['emoji_count'] > 2, r['sentence_count'] < 1 or r['sentence_count'] > 3), reverse=True)[:30]
    for row in candidates:
        md_lines.append(f"- {row['id']}｜{row['question']}")

    # Sample 30
    md_lines.append("")
    md_lines.append("## 抽樣 30 題")
    sample = sorted(all_rows, key=lambda r: r['id'] or "")[:30]
    for row in sample:
        md_lines.append("")
        md_lines.append(f"**{row['id']}**")
        md_lines.append(f"- Q: {row['question']}")
        md_lines.append(f"- Options: {', '.join([str(o) for o in row['options']])}")
        md_lines.append(f"- A: {row['answer']}")
        md_lines.append(f"- E: {row['explanation']}")

    (reports_dir / "qbank_audit.md").write_text("\n".join(md_lines), encoding="utf-8")

    # qbank_full_by_pack.md
    by_pack = defaultdict(list)
    for row in all_rows:
        by_pack[row['pack']].append(row)

    full_lines = []
    full_lines.append("# QBank 全題庫（分科）")
    for pack in sorted(by_pack.keys()):
        full_lines.append("")
        full_lines.append(f"## {pack}")
        for row in by_pack[pack]:
            full_lines.append("")
            full_lines.append(f"**{row['id']}**")
            full_lines.append(f"- Q: {row['question']}")
            full_lines.append(f"- Options: {', '.join([str(o) for o in row['options']])}")
            full_lines.append(f"- A: {row['answer']}")
            full_lines.append(f"- E: {row['explanation']}")

    (reports_dir / "qbank_full_by_pack.md").write_text("\n".join(full_lines), encoding="utf-8")

    print("Done. Next: python3 tools/qbank_audit.py && git add reports/qbank_audit.md reports/qbank_full_by_pack.md reports/qbank_audit.json && git commit -m \"audit: update qbank reports\" && git push")


if __name__ == "__main__":
    main()
