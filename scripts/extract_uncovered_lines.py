#!/usr/bin/env python3
import os
import re
import sys

def find_uncovered_lines_in_html(content):
    uncovered = []
    # Split into table rows
    rows = re.findall(r"<tr>(.*?)</tr>", content, flags=re.DOTALL)
    for tr in rows:
        m = re.search(r"name=['\"]L(\d+)['\"]", tr)
        if not m:
            continue
        line_no = int(m.group(1))
        # uncovered executable lines have a <td class='uncovered-line'><pre>0</pre>
        if re.search(r"<td[^>]*class=['\"]uncovered-line['\"][^>]*>\s*<pre>\s*\d+\s*</pre>", tr):
            uncovered.append(line_no)
    return uncovered

def extract_source_path(content):
    m = re.search(r"<div class=['\"]source-name-title['\"]>.*?<pre>(.*?)</pre>.*?</div>", content, flags=re.DOTALL)
    if m:
        return m.group(1).strip()
    # fallback: look for first absolute path occurrence
    m2 = re.search(r"(/[^<>\n]+/[^<>\n]+\.swift)", content)
    return m2.group(1).strip() if m2 else None

def main():
    here = os.path.abspath(os.path.dirname(__file__))
    repo_root = os.path.abspath(os.path.join(here, '..'))
    coverage_html_root = os.path.join(repo_root, 'coverage', 'coverage')
    if not os.path.isdir(coverage_html_root):
        print('Coverage HTML directory not found:', coverage_html_root, file=sys.stderr)
        sys.exit(2)

    results = {}
    for dirpath, dirs, files in os.walk(coverage_html_root):
        for fn in files:
            if not fn.endswith('.html'):
                continue
            path = os.path.join(dirpath, fn)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except Exception as e:
                print('Failed to read', path, e, file=sys.stderr)
                continue
            src = extract_source_path(content)
            if not src:
                continue
            # Only include files inside the repo
            try:
                rel = os.path.relpath(src, repo_root)
            except Exception:
                rel = src
            if rel.startswith('..'):
                # skip files outside repository
                continue
            uncovered = find_uncovered_lines_in_html(content)
            if uncovered:
                uncovered.sort()
                results[rel] = uncovered

    out_path = os.path.join(repo_root, 'coverage-uncovered.txt')
    with open(out_path, 'w', encoding='utf-8') as out:
        for rel, lines in sorted(results.items()):
            out.write(f"{rel}:{','.join(str(x) for x in lines)}\n")

    print(f'Wrote {len(results)} files to', out_path)

if __name__ == '__main__':
    main()
