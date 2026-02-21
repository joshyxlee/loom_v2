#!/usr/bin/env python3
"""
Usage:
  python3 tools/qbank_audit.py

Outputs:
  reports/qbank_audit.md
  reports/qbank_audit.html
  reports/qbank_audit_summary.json
  reports/qbank_audit.json
  reports/qbank_full_by_pack.md
  reports/qbank_quality_flags.md
"""
import json
import sys
import re
from pathlib import Path
from datetime import datetime
from collections import Counter, defaultdict
from itertools import combinations

BANNED_PHRASES = [
    "看到關鍵字",
    "方向就會",
    "符合題意",
    "常見誤解",
    "容易選成",
    "因此選",
    "排除",
]

CATCHPHRASES = [
    "重點",
    "想成",
    "對味",
    "登場",
    "很扯",
    "沒想到",
    "其實就是",
    "關鍵",
]

LIMITS = {
    "min_len": 18,
    "max_len": 60,
    "min_sentences": 1,
    "max_sentences": 2,
    "max_emoji": 1,
    "max_exclam": 2,
    "max_tilde": 1,
    "catchphrase_warn": 8,
    "catchphrase_fail": 15,
    "opening_warn": 3,
    "opening_fail": 6,
    "similarity_pair_fail_ratio": 0.05,
    "restatement_overlap": 0.6,
}

EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF]")

KNOWLEDGE_HINTS = [
    "因為",
    "所以",
    "例如",
    "比如",
    "像",
    "規則",
    "制度",
    "機制",
    "流程",
    "指標",
    "單位",
    "年",
    "公里",
    "公尺",
    "秒",
    "%",
]

CONNECTORS = ["就是", "其實", "也就是", "答案是", "代表", "指的是", "等於", "為", "為了", "說的就是", "主角是"]


def load_questions(path: Path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, list):
        raise ValueError(f"Invalid JSON structure in {path}: expected a list")
    return data


def normalize(text: str) -> str:
    return re.sub(r"[\s\p{P}]+", "", (text or "").lower())


def cjk_len(text: str) -> int:
    return len(re.sub(r"\s+", "", text or ""))


def sentence_count(text: str) -> int:
    return len(re.findall(r"[。！？]", text or ""))


def emoji_count(text: str) -> int:
    return len(EMOJI_RE.findall(text or ""))


def exclam_count(text: str) -> int:
    return (text or "").count("!") + (text or "").count("！")


def tilde_count(text: str) -> int:
    return (text or "").count("~")


def detect_banned(explanation: str):
    hits = []
    for phrase in BANNED_PHRASES:
        if phrase in explanation:
            hits.append(phrase)
    return hits


def has_knowledge(explanation: str) -> bool:
    if any(h in explanation for h in KNOWLEDGE_HINTS):
        return True
    if re.search(r"\d", explanation or ""):
        return True
    return False


def restatement_fail(answer: str, explanation: str) -> bool:
    if not answer:
        return False
    a = re.sub(r"[\W_]+", "", answer)
    e = re.sub(r"[\W_]+", "", explanation)
    if not e:
        return True

    # explicit restatement patterns
    for pat in ["主角是", "這件事說的就是", "本身就是例子", "重點就是"]:
        if pat in explanation:
            return True

    # if answer dominates the explanation
    if a and a in e and len(a) / max(len(e), 1) > 0.5:
        return True

    # remove answer + connectors, see if anything substantial left
    stripped = e
    if a:
        stripped = stripped.replace(a, "")
    for c in CONNECTORS:
        stripped = stripped.replace(re.sub(r"[\W_]+", "", c), "")
    if len(stripped) < 8:
        return True

    # ratio of explanation chars that come from answer or connectors
    allowed = a
    for c in CONNECTORS:
        allowed += c
    covered = sum(1 for ch in e if ch in allowed)
    if covered / max(len(e), 1) >= 0.7:
        return True

    # token overlap + no extra tokens
    a_tokens = set(re.findall(r"[A-Za-z0-9]+|[\u4e00-\u9fff]+", answer))
    e_tokens = set(re.findall(r"[A-Za-z0-9]+|[\u4e00-\u9fff]+", explanation))
    if not e_tokens:
        return True
    overlap = len(a_tokens & e_tokens) / max(len(e_tokens), 1)
    extra_tokens = [t for t in e_tokens if t not in a_tokens and len(t) >= 2]
    if overlap > LIMITS["restatement_overlap"] and (not extra_tokens) and not has_knowledge(explanation):
        return True
    return False


def jaccard_3gram(a: str, b: str) -> float:
    def grams(s):
        s = re.sub(r"\s+", "", s)
        return {s[i:i+3] for i in range(max(len(s) - 2, 0))}
    ga = grams(a)
    gb = grams(b)
    if not ga or not gb:
        return 0.0
    return len(ga & gb) / len(ga | gb)


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
    by_pack = defaultdict(list)

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

            row = {
                "pack": path.name,
                "id": qid,
                "question": prompt,
                "options": options,
                "answer": f"{answer_index} - {answer_text}",
                "answer_text": answer_text,
                "explanation": explanation,
            }
            all_rows.append(row)
            by_pack[path.name].append(row)

    # Per-item checks
    for row in all_rows:
        exp = row["explanation"]
        row["len"] = cjk_len(exp)
        row["sentences"] = sentence_count(exp)
        row["emoji"] = emoji_count(exp)
        row["exclam"] = exclam_count(exp)
        row["tilde"] = tilde_count(exp)
        row["banned_hits"] = detect_banned(exp)
        row["knowledge_ok"] = has_knowledge(exp)
        row["restatement_fail"] = restatement_fail(row["answer_text"], exp)

        row["len_fail"] = row["len"] < LIMITS["min_len"] or row["len"] > LIMITS["max_len"]
        row["sentence_fail"] = row["sentences"] < LIMITS["min_sentences"] or row["sentences"] > LIMITS["max_sentences"]
        row["emoji_fail"] = row["emoji"] > LIMITS["max_emoji"]
        row["exclam_fail"] = row["exclam"] > LIMITS["max_exclam"]
        row["tilde_fail"] = row["tilde"] > LIMITS["max_tilde"]
        row["banned_fail"] = len(row["banned_hits"]) > 0
        row["knowledge_fail"] = not row["knowledge_ok"]

    # Catchphrase repetition per pack
    catchphrase_stats = defaultdict(lambda: defaultdict(list))
    for row in all_rows:
        for cp in CATCHPHRASES:
            if cp in row["explanation"]:
                catchphrase_stats[row["pack"]][cp].append(row["id"])

    catchphrase_flags = defaultdict(dict)
    for pack, cps in catchphrase_stats.items():
        for cp, ids in cps.items():
            count = len(ids)
            level = "OK"
            if count > LIMITS["catchphrase_fail"]:
                level = "FAIL"
            elif count > LIMITS["catchphrase_warn"]:
                level = "WARN"
            catchphrase_flags[pack][cp] = {
                "count": count,
                "level": level,
                "ids": ids[:30],
            }

    # Opening repeat per pack (first 10 chars)
    opening_flags = defaultdict(list)
    for pack, rows in by_pack.items():
        openings = defaultdict(list)
        for row in rows:
            opening = (row["explanation"] or "")[:10]
            openings[opening].append(row["id"])
        for opening, ids in openings.items():
            if len(ids) >= LIMITS["opening_fail"]:
                opening_flags[pack].append({"opening": opening, "level": "FAIL", "ids": ids})
            elif len(ids) >= LIMITS["opening_warn"]:
                opening_flags[pack].append({"opening": opening, "level": "WARN", "ids": ids})

    # Similarity per pack
    similarity_pairs = defaultdict(list)
    similarity_fail = defaultdict(bool)
    for pack, rows in by_pack.items():
        pairs = []
        for a, b in combinations(rows, 2):
            score = jaccard_3gram(a["explanation"], b["explanation"])
            if score >= 0.6:
                pairs.append((a["id"], b["id"], round(score, 3)))
        similarity_pairs[pack] = sorted(pairs, key=lambda x: x[2], reverse=True)[:30]
        if rows:
            ratio = len(pairs) / max(len(rows) * (len(rows)-1) / 2, 1)
            if ratio > LIMITS["similarity_pair_fail_ratio"]:
                similarity_fail[pack] = True

    # Aggregate failures
    restatement_ids = []
    banned_ids = []
    knowledge_ids = []
    length_ids = []
    sentence_ids = []
    emoji_ids = []
    exclam_ids = []
    tilde_ids = []

    for row in all_rows:
        if row["restatement_fail"]:
            restatement_ids.append(row["id"])
        if row["banned_fail"]:
            banned_ids.append(row["id"])
        if row["knowledge_fail"]:
            knowledge_ids.append(row["id"])
        if row["len_fail"]:
            length_ids.append(row["id"])
        if row["sentence_fail"]:
            sentence_ids.append(row["id"])
        if row["emoji_fail"]:
            emoji_ids.append(row["id"])
        if row["exclam_fail"]:
            exclam_ids.append(row["id"])
        if row["tilde_fail"]:
            tilde_ids.append(row["id"])

    summary = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_questions": len(all_rows),
        "banned_phrase_hits": len(banned_ids),
        "restatement_fail_count": len(restatement_ids),
        "knowledge_fail_count": len(knowledge_ids),
        "char_length_violations": len(length_ids),
        "sentence_count_violations": len(sentence_ids),
        "emoji_violations": len(emoji_ids),
        "exclam_violations": len(exclam_ids),
        "tilde_violations": len(tilde_ids),
        "similarity_fail_packs": [p for p, v in similarity_fail.items() if v],
        "catchphrase_flags": catchphrase_flags,
        "opening_repeat_flags": opening_flags,
    }

    # Write summary json
    (reports_dir / "qbank_audit_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # Detailed json
    (reports_dir / "qbank_audit.json").write_text(
        json.dumps({"summary": summary, "items": all_rows, "similarity_pairs": similarity_pairs}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    # qbank_audit.md
    md_lines = []
    md_lines.append("# QBank Audit 摘要")
    md_lines.append("")
    md_lines.append(f"- 產生時間：{summary['generated_at']}")
    md_lines.append(f"- 題目數：{summary['total_questions']}")
    md_lines.append(f"- banned phrase 命中：{summary['banned_phrase_hits']}")
    md_lines.append(f"- restatement 失敗：{summary['restatement_fail_count']}")
    md_lines.append(f"- knowledge nugget 失敗：{summary['knowledge_fail_count']}")
    md_lines.append(f"- 字數違規：{summary['char_length_violations']}")
    md_lines.append(f"- 句數違規：{summary['sentence_count_violations']}")
    md_lines.append(f"- emoji 違規：{summary['emoji_violations']}")
    md_lines.append(f"- 驚嘆號違規：{summary['exclam_violations']}")
    md_lines.append(f"- 波浪號違規：{summary['tilde_violations']}")
    md_lines.append("")

    md_lines.append("## Catchphrase 統計")
    for pack, cps in catchphrase_flags.items():
        md_lines.append(f"- {pack}")
        for cp, info in cps.items():
            md_lines.append(f"  - {cp}: {info['count']} ({info['level']})")

    md_lines.append("")
    md_lines.append("## Opening Repeat")
    for pack, items in opening_flags.items():
        md_lines.append(f"- {pack}")
        for it in items:
            md_lines.append(f"  - {it['level']}：{it['opening']} ({len(it['ids'])})")

    md_lines.append("")
    md_lines.append("## Similarity Pairs (Top 30 per pack)")
    for pack, pairs in similarity_pairs.items():
        if not pairs:
            continue
        md_lines.append(f"- {pack}")
        for a, b, score in pairs:
            md_lines.append(f"  - {a} / {b}: {score}")

    (reports_dir / "qbank_audit.md").write_text("\n".join(md_lines), encoding="utf-8")

    # HTML (simple)
    html = "<html><head><meta charset='utf-8'><title>QBank Audit</title></head><body>"
    html += "<h1>QBank Audit 摘要</h1>"
    html += "<ul>"
    for k in [
        "generated_at",
        "total_questions",
        "banned_phrase_hits",
        "restatement_fail_count",
        "knowledge_fail_count",
        "char_length_violations",
        "sentence_count_violations",
        "emoji_violations",
        "exclam_violations",
        "tilde_violations",
    ]:
        html += f"<li>{k}: {summary[k]}</li>"
    html += "</ul>"
    html += "</body></html>"
    (reports_dir / "qbank_audit.html").write_text(html, encoding="utf-8")

    # qbank_full_by_pack.md
    full_lines = []
    full_lines.append("# QBank 全題庫（分科）")
    for pack, rows in sorted(by_pack.items()):
        full_lines.append("")
        full_lines.append(f"## {pack}")
        for row in rows:
            full_lines.append("")
            full_lines.append(f"**{row['id']}**")
            full_lines.append(f"- Q: {row['question']}")
            full_lines.append(f"- Options: {', '.join([str(o) for o in row['options']])}")
            full_lines.append(f"- A: {row['answer']}")
            full_lines.append(f"- E: {row['explanation']}")
    (reports_dir / "qbank_full_by_pack.md").write_text("\n".join(full_lines), encoding="utf-8")

    # qbank_quality_flags.md
    flags = []
    flags.append("# QBank Quality Flags")
    flags.append("")
    flags.append("## Restatement")
    for row in all_rows:
        if row["restatement_fail"]:
            flags.append(f"- {row['id']} | {row['answer_text']} | {row['explanation']}")
    flags.append("")
    flags.append("## Similarity")
    for pack, pairs in similarity_pairs.items():
        for a, b, score in pairs:
            flags.append(f"- {pack}: {a} / {b} ({score})")
    flags.append("")
    flags.append("## Opening Repeat")
    for pack, items in opening_flags.items():
        for it in items:
            if it["level"] == "FAIL":
                flags.append(f"- {pack}: {it['opening']} ({len(it['ids'])})")
    flags.append("")
    flags.append("## Catchphrase Overuse")
    for pack, cps in catchphrase_flags.items():
        for cp, info in cps.items():
            if info["level"] == "FAIL":
                flags.append(f"- {pack}: {cp} ({info['count']})")

    (reports_dir / "qbank_quality_flags.md").write_text("\n".join(flags), encoding="utf-8")

    print(
        "Done. Next: python3 tools/qbank_audit.py && git add reports/qbank_audit.md reports/qbank_audit.html reports/qbank_audit_summary.json reports/qbank_full_by_pack.md reports/qbank_quality_flags.md reports/qbank_audit.json && git commit -m \"audit: update qbank reports\" && git push"
    )


if __name__ == "__main__":
    main()
