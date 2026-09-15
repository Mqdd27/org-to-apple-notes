#!/usr/bin/env python3
"""
Post-processes pandoc's org->HTML output so it renders nicely in Apple Notes:
  1. Shrinks oversized headings (org headlines all come out as <h1>)
  2. Converts pandoc's checkbox <input type="checkbox"> into Apple Notes'
     native checklist format: <ul class="checklist"><li class="checked">...

Usage: fix_for_notes.py <input.html> <output.html>
"""

import sys
import re
from bs4 import BeautifulSoup

def fix_headings(soup):
    # Apple Notes only really distinguishes 3 sizes (Title/Heading/Subheading).
    # Org's TODO/DONE keyword spans also get dragged into <h1>, so strip those
    # wrapper spans and shrink the tag itself.
    for level, new_tag in [("h1", "h2"), ("h2", "h3"), ("h3", "h3")]:
        for tag in soup.find_all(level):
            # unwrap the todo/done keyword span but keep its text (e.g. "TODO", "DONE")
            for span in tag.find_all("span", class_=re.compile(r"\btodo\b|\bdone\b")):
                span.unwrap()
            tag.name = new_tag

def fix_checklists(soup):
    for ul in soup.find_all("ul", class_="task-list"):
        ul["class"] = ["checklist"]
        for li in ul.find_all("li"):
            checkbox = li.find("input", type="checkbox")
            is_checked = checkbox is not None and checkbox.has_attr("checked")

            # pandoc wraps text in <label>...</label>; pull the plain text out
            label = li.find("label")
            text = label.get_text(strip=True) if label else li.get_text(strip=True)

            li.clear()
            li.append(text)
            if is_checked:
                li["class"] = ["checked"]

def main():
    if len(sys.argv) != 3:
        print("Usage: fix_for_notes.py <input.html> <output.html>")
        sys.exit(1)

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "html.parser")

    fix_headings(soup)
    fix_checklists(soup)

    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(str(soup))

if __name__ == "__main__":
    main()
