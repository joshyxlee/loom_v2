#!/usr/bin/env python3
import json
import sys
import os
import hashlib
from pathlib import Path
from html import escape
from datetime import datetime
from collections import Counter

BANNED_PHRASES = ["這種題", "容易選", "表面上", "陷阱", "誤導", "直覺"]


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
    short_explanations = []
    banned_hits = []

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

            issues = []
            if len(explanation.strip()) < 40:
                issues.append("short_explanation")
                short_explanations.append(qid)

            for phrase in BANNED_PHRASES:
                if phrase in explanation:
                    issues.append(f"banned_phrase:{phrase}")
                    banned_hits.append({"id": qid, "phrase": phrase})

            hash_input = f"{qid or ''}{prompt}{explanation}".encode("utf-8")
            sha256 = hashlib.sha256(hash_input).hexdigest()
            all_rows.append({
                "pack": path.name,
                "source_file": path.name,
                "id": qid,
                "question": prompt,
                "options": options,
                "answer": f"{answer_index} - {answer_text}",
                "explanation": explanation,
                "sha256": sha256,
                "issues": issues,
            })

    # Duplicate checks
    id_counts = Counter(id_list)
    duplicate_ids = sorted([i for i, c in id_counts.items() if i and c > 1])

    prompt_counts = Counter([p for p in prompt_list if p])
    duplicate_prompts = sorted([p for p, c in prompt_counts.items() if c > 1])

    issues_count = sum(1 for row in all_rows if row["issues"]) + len(duplicate_ids)

    # Summary JSON
    summary = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_packs": len(question_files),
        "total_questions": len(all_rows),
        "issues_count": issues_count,
        "duplicate_ids": duplicate_ids,
        "duplicate_prompts": duplicate_prompts,
        "short_explanations": short_explanations,
        "banned_phrase_hits": banned_hits,
    }

    summary_path = reports_dir / "qbank_audit_summary.json"
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    # HTML report
    rows_html = []
    for row in all_rows:
        issue_class = "issue" if row["issues"] else ""
        issues_text = ", ".join(row["issues"])
        options_html = "<ol>" + "".join(f"<li>{escape(str(opt))}</li>" for opt in row["options"]) + "</ol>"
        rows_html.append(
            "<tr class='row {cls}'>"
            "<td>{source}</td>"
            "<td>{qid}</td>"
            "<td>{question}</td>"
            "<td>{options}</td>"
            "<td>{answer}</td>"
            "<td>{explanation}</td>"
            "<td>{sha256}</td>"
            "<td>{issues}</td>"
            "</tr>".format(
                cls=issue_class,
                source=escape(str(row["source_file"])),
                qid=escape(str(row["id"])),
                question=escape(str(row["question"])),
                options=options_html,
                answer=escape(str(row["answer"])),
                explanation=escape(str(row["explanation"])),
                sha256=escape(str(row["sha256"])),
                issues=escape(issues_text),
            )
        )

    html = f"""
<!doctype html>
<html lang=\"zh-Hant\">
<head>
  <meta charset=\"utf-8\" />
  <title>QBank Audit Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .search {{ margin-bottom: 16px; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; vertical-align: top; }}
    th {{ background: #f3f3f3; }}
    tr.issue {{ background: #ffe8e8; }}
  </style>
</head>
<body>
  <h1>QBank Audit Report</h1>
  <div class=\"search\">
    <label for=\"searchBox\"><strong>Search:</strong></label>
    <input id=\"searchBox\" type=\"text\" placeholder=\"Type to filter\" />
  </div>
  <table>
    <thead>
      <tr>
        <th>Source File</th>
        <th>ID</th>
        <th>Question</th>
        <th>Options</th>
        <th>Answer</th>
        <th>Explanation</th>
        <th>SHA256</th>
        <th>Issues</th>
      </tr>
    </thead>
    <tbody>
      {''.join(rows_html)}
    </tbody>
  </table>
  <script>
    const searchBox = document.getElementById('searchBox');
    searchBox.addEventListener('input', () => {{
      const term = searchBox.value.toLowerCase();
      document.querySelectorAll('tbody tr').forEach(row => {{
        const text = row.innerText.toLowerCase();
        row.style.display = text.includes(term) ? '' : 'none';
      }});
    }});
  </script>
</body>
</html>
"""

    html_path = reports_dir / "qbank_audit.html"
    html_path.write_text(html, encoding="utf-8")

    # Fail if duplicate IDs exist
    if duplicate_ids:
        print(f"ERROR: Duplicate IDs found: {duplicate_ids}", file=sys.stderr)
        sys.exit(1)

    # best-effort open on macOS
    if sys.platform == "darwin":
        try:
            import subprocess
            subprocess.run(["open", str(html_path)], check=False)
        except Exception:
            print(f"Report generated at: {html_path}")


if __name__ == "__main__":
    main()
