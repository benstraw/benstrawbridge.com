#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import tomllib
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urlparse


REPO_ROOT = Path(__file__).resolve().parent.parent
LINKS_ROOT = REPO_ROOT / "content" / "links"
REPORT_PATH = REPO_ROOT / "LINK_MIGRATION_REPORT.md"

LINK_RE = re.compile(r"^-\s+\[(?P<title>.*?)\]\((?P<url>https?://[^)]+)\)(?P<tail>.*)$")
PLAIN_URL_RE = re.compile(r"^-\s+(?P<url>https?://\S+)\s*$")
HEADING_RE = re.compile(r"^(#{2,6})\s+(.*\S)\s*$")

CATEGORY_DEFAULT_TAGS = {
    "art": ["art"],
    "analytics": ["analytics"],
    "blogroll": ["blogroll"],
    "css": ["css"],
    "crypto": ["crypto"],
    "email": ["email"],
    "fonts-icons": ["design"],
    "hugo": ["hugo"],
    "machine-learning-and-artificial-intelligence": ["ai"],
    "mapping": ["mapping"],
    "oblargh": ["oblargh"],
    "services": ["services"],
    "the-web": ["web"],
    "testing": ["testing"],
    "tools": ["developer-tools"],
}

SECTION_TAGS = {
    "art tech services companies": ["art-tech"],
    "coding agents": ["coding-agents"],
    "ecommerce": ["ecommerce"],
    "email forwarding": ["email"],
    "finance": ["finance"],
    "fonts": ["fonts"],
    "general": ["general"],
    "hugo image processing": ["images"],
    "hugo modules": ["modules"],
    "hugo recipe websites": ["recipes"],
    "hugo themes": ["themes"],
    "icons": ["icons"],
    "image gallery resources": ["image-gallery"],
    "llm testing tools": ["llm-testing"],
    "llm tools": ["llm"],
    "ml datasets": ["datasets"],
    "model evaluation & validation tools": ["evaluation"],
    "newsletter platforms": ["newsletter"],
    "ocr": ["ocr"],
    "on automation": ["automation"],
    "payments": ["payments"],
    "performance and monitoring tools": ["monitoring"],
    "portfolio sites": ["portfolio"],
    "setup": ["setup"],
    "stress testing and edge case testing": ["testing"],
    "testing bias & fairness": ["fairness"],
    "unit testing for machine learning": ["testing"],
}

TITLE_TAGS = {
    "tailwind": ["tailwind"],
    "hugo": ["hugo"],
    "css": ["css"],
    "font": ["fonts"],
    "icon": ["icons"],
    "analytics": ["analytics"],
    "ocr": ["ocr"],
}

DRAFT_CATEGORIES = {"email", "services", "testing"}
SKIP_LEAF_FILES = {"_index.md"}
HISTORICAL_LINKS_PATHS = [
    "content/links/index.md",
    "content/posts/links/index.md",
    "content/posts/links/links.md",
    "content/posts/links.md",
]


@dataclass
class LegacyLink:
    title: str
    url: str
    category: str
    source_path: str
    source_title: str
    source_date: str
    source_draft: bool
    section: str | None = None
    inline_description: str = ""
    blockquote_description: str = ""
    bullet_text: str = ""


@dataclass
class LegacyCategoryPage:
    path: Path
    title: str
    front_matter: str
    draft: bool
    intro_paragraphs: list[str] = field(default_factory=list)
    section_notes: list[tuple[str, str]] = field(default_factory=list)
    sections: list[str] = field(default_factory=list)
    category_slug: str = ""


@dataclass
class ExistingLeafPage:
    path: Path
    front_matter: dict
    body: str


def read_content_file(path: Path) -> tuple[str, dict, str]:
    text = path.read_text()
    if not text.startswith("+++\n"):
        raise ValueError(f"{path} is missing TOML front matter")
    _, fm, body = text.split("+++", 2)
    return text, tomllib.loads(fm), body.lstrip("\n")


def normalize_space(value: str) -> str:
    return " ".join(value.strip().split())


def normalize_date_value(value) -> str:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "link"


def title_case_title(value: str) -> str:
    return value.replace("*", "").strip()


def display_title_from_url(url: str) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.lower().removeprefix("www.")
    host = re.sub(r"\.(com|org|net|io|co|me|dev|ai|uk)$", "", host)
    host = re.sub(r"[^a-z0-9]+", " ", host)

    path = parsed.path.strip("/")
    if path:
        path = re.sub(r"[^a-zA-Z0-9]+", " ", path)
        title = f"{host} {path}".strip()
    else:
        title = host.strip()

    return title.title() or url


def extract_description_tail(tail: str) -> str:
    tail = tail.strip()
    if not tail:
        return ""
    if tail.startswith("."):
        return normalize_space(tail[1:].strip())
    if tail.startswith("-"):
        return normalize_space(tail[1:].strip())
    return ""


def parse_legacy_category_page(path: Path) -> tuple[LegacyCategoryPage, list[LegacyLink]]:
    raw_text = path.read_text()
    if not raw_text.startswith("+++\n"):
        raise ValueError(f"{path} is missing front matter")

    _, fm_text, body = raw_text.split("+++", 2)
    front_matter = tomllib.loads(fm_text)
    lines = body.lstrip("\n").splitlines()

    page = LegacyCategoryPage(
        path=path,
        title=front_matter["title"],
        front_matter=fm_text.strip(),
        draft=bool(front_matter.get("draft", False)),
        category_slug=path.parent.name,
    )

    results: list[LegacyLink] = []
    current_heading: str | None = None
    current_heading_seen_link = False
    intro_buffer: list[str] = []

    idx = 0
    while idx < len(lines):
        line = lines[idx]
        stripped = line.strip()

        if stripped == "<!--more-->":
            break

        heading_match = HEADING_RE.match(stripped)
        if heading_match:
            current_heading = normalize_space(heading_match.group(2))
            current_heading_seen_link = False
            page.sections.append(current_heading)
            idx += 1
            continue

        if stripped.startswith(">"):
            quote_lines = [normalize_space(stripped.lstrip(">").strip())]
            idx += 1
            while idx < len(lines) and lines[idx].strip().startswith(">"):
                quote_lines.append(normalize_space(lines[idx].strip().lstrip(">").strip()))
                idx += 1
            quote_text = " ".join([q for q in quote_lines if q]).strip()
            if quote_text:
                if current_heading and not current_heading_seen_link:
                    page.section_notes.append((current_heading, quote_text))
                else:
                    page.intro_paragraphs.append(quote_text)
            continue

        if not stripped:
            idx += 1
            continue

        link_match = LINK_RE.match(stripped)
        plain_match = PLAIN_URL_RE.match(stripped)
        if link_match or plain_match:
            if link_match:
                title = normalize_space(link_match.group("title"))
                url = link_match.group("url").strip()
                description = extract_description_tail(link_match.group("tail"))
            else:
                url = plain_match.group("url").strip()
                title = url
                description = ""

            blockquote_lines: list[str] = []
            lookahead = idx + 1
            while lookahead < len(lines):
                next_stripped = lines[lookahead].strip()
                if not next_stripped:
                    lookahead += 1
                    continue
                if next_stripped.startswith(">"):
                    blockquote_lines.append(normalize_space(next_stripped.lstrip(">").strip()))
                    lookahead += 1
                    continue
                break

            blockquote_description = " ".join([q for q in blockquote_lines if q]).strip()
            results.append(
                LegacyLink(
                    title=title,
                    url=url,
                    category=path.parent.name,
                    source_path=str(path.relative_to(REPO_ROOT)),
                    source_title=front_matter["title"],
                    source_date=normalize_date_value(front_matter["date"]),
                    source_draft=bool(front_matter.get("draft", False)),
                    section=current_heading,
                    inline_description=description,
                    blockquote_description=blockquote_description,
                    bullet_text=stripped,
                )
            )
            current_heading_seen_link = True
            idx = lookahead if blockquote_lines else idx + 1
            continue

        intro_buffer.append(stripped)
        idx += 1

    if intro_buffer:
        page.intro_paragraphs.append("\n".join(intro_buffer).strip())

    return page, results


def load_existing_leaf_pages() -> dict[str, ExistingLeafPage]:
    by_url: dict[str, ExistingLeafPage] = {}
    for path in sorted(LINKS_ROOT.glob("*.md")):
        if path.name in SKIP_LEAF_FILES:
            continue
        _, front_matter, body = read_content_file(path)
        link_url = front_matter.get("link_url")
        if not link_url:
            continue
        by_url[str(link_url)] = ExistingLeafPage(path=path, front_matter=front_matter, body=body.rstrip() + ("\n" if body.strip() else ""))
    return by_url


def front_matter_candidate_paths(front_matter: dict) -> list[str]:
    candidate_paths: list[str] = []

    legacy_source = front_matter.get("legacy_source")
    if isinstance(legacy_source, str) and legacy_source:
        candidate_paths.append(legacy_source)
    elif isinstance(legacy_source, list):
        candidate_paths.extend([str(value) for value in legacy_source if str(value).strip()])

    link_sections = front_matter.get("link_sections")
    if not link_sections:
        link_sections = front_matter.get("categories", []) or []

    for link_section in link_sections:
        category_path = f"content/links/{link_section}/index.md"
        if category_path not in candidate_paths:
            candidate_paths.append(category_path)

    for historical_path in HISTORICAL_LINKS_PATHS:
        if historical_path not in candidate_paths:
            candidate_paths.append(historical_path)

    return candidate_paths


def git_first_add_date_for_paths(candidate_paths: list[str], url: str, bullet_text: str = "") -> str | None:
    deduped_paths = []
    for path in candidate_paths:
        if path and path not in deduped_paths:
            deduped_paths.append(path)

    candidates: list[str] = []
    needles = [url]
    if bullet_text:
        needles.append(bullet_text)
    for needle in needles:
        for path in deduped_paths:
            try:
                proc = subprocess.run(
                    [
                        "git",
                        "log",
                        "--reverse",
                        "--format=%ad",
                        "--date=iso-strict",
                        f"-S{needle}",
                        "--",
                        path,
                    ],
                    cwd=REPO_ROOT,
                    capture_output=True,
                    text=True,
                    check=True,
                )
            except subprocess.CalledProcessError:
                continue
            dates = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
            candidates.extend(dates)

    if not candidates:
        return None
    return min(candidates)


def git_first_add_date(source_path: str, url: str, bullet_text: str) -> str | None:
    candidate_paths = [source_path, *HISTORICAL_LINKS_PATHS]
    return git_first_add_date_for_paths(candidate_paths, url, bullet_text)


def choose_title(url: str, items: list[LegacyLink], existing: ExistingLeafPage | None) -> str:
    if existing and existing.front_matter.get("title"):
        return str(existing.front_matter["title"])

    non_url_items = [item for item in items if item.title != item.url]
    if not non_url_items:
        return display_title_from_url(url)

    def score(item: LegacyLink) -> tuple[int, int, int]:
        title = item.title
        clean_title = title_case_title(title)
        score_value = 0
        if title != item.url:
            score_value += 5
        if clean_title.lower() != slugify(clean_title).replace("-", " "):
            score_value += 1
        if "." not in clean_title:
            score_value += 2
        if len(clean_title.split()) >= 2:
            score_value += 1
        return (score_value, len(clean_title), -non_url_items.index(item))

    best = max(non_url_items, key=score)
    return title_case_title(best.title)


def choose_description(items: list[LegacyLink], existing: ExistingLeafPage | None) -> str:
    existing_description = ""
    if existing:
        existing_description = normalize_space(str(existing.front_matter.get("description", "")))
        if existing_description:
            return existing_description

    for item in items:
        if item.inline_description:
            return item.inline_description
    for item in items:
        if item.blockquote_description:
            return item.blockquote_description
    return ""


def infer_tags(category: str, sections: list[str], title: str, existing_tags: list[str]) -> list[str]:
    tags: set[str] = {tag for tag in existing_tags if tag}
    for tag in CATEGORY_DEFAULT_TAGS.get(category, []):
        tags.add(tag)

    if category == "fonts-icons":
        lowered_sections = {section.lower() for section in sections}
        if "icons" in lowered_sections:
            tags.add("icons")
        if "fonts" in lowered_sections:
            tags.add("fonts")

    for section in sections:
        for tag in SECTION_TAGS.get(section.lower(), []):
            tags.add(tag)

    lowered_title = title.lower()
    for needle, extra_tags in TITLE_TAGS.items():
        if needle in lowered_title:
            tags.update(extra_tags)

    return sorted(tags)


def render_toml_list(values: list[str]) -> str:
    escaped = [json.dumps(value, ensure_ascii=False) for value in values]
    return "[" + ", ".join(escaped) + "]"


def render_leaf_front_matter(record: dict, existing_body: str) -> str:
    lines = [
        "+++",
        f"title = {json.dumps(record['title'], ensure_ascii=False)}",
        f"date = {record['date']}",
        f"draft = {'true' if record['draft'] else 'false'}",
        f"link_url = {json.dumps(record['link_url'], ensure_ascii=False)}",
        f"description = {json.dumps(record['description'], ensure_ascii=False)}",
        f"link_sections = {render_toml_list(record['link_sections'])}",
        f"tags = {render_toml_list(record['tags'])}",
    ]
    if record["legacy_sections"]:
        lines.append(f"legacy_sections = {render_toml_list(record['legacy_sections'])}")
    if len(record["legacy_source"]) == 1:
        lines.append(f"legacy_source = {json.dumps(record['legacy_source'][0], ensure_ascii=False)}")
    else:
        lines.append(f"legacy_source = {render_toml_list(record['legacy_source'])}")
    lines.append("+++")
    body = existing_body.strip("\n")
    if body:
        return "\n".join(lines) + "\n\n" + body + "\n"
    return "\n".join(lines) + "\n"


def render_landing_front_matter(front_matter_text: str) -> str:
    lines = front_matter_text.strip().splitlines()
    if not any(line.strip().startswith("link_section_landing") for line in lines):
        lines.append("link_section_landing = true")
    return "\n".join(lines)


def build_category_landing_body(page: LegacyCategoryPage) -> str:
    lines: list[str] = []
    if page.intro_paragraphs:
        for paragraph in page.intro_paragraphs:
            cleaned = paragraph.strip()
            if (
                "This category now lives in the individual link archive." in cleaned
                or "This link section now lives in the individual link archive." in cleaned
                or "Use the main [Link Graveyard](/links/) page for search, tag filters, and cross-category browsing." in cleaned
            ):
                continue
            lines.append(cleaned)
            lines.append("")

    lines.append(
        f"This link section now lives in the individual link archive. Browse the filtered [Link Graveyard](/links/?section={page.category_slug}) to see every `{page.category_slug}` link."
    )

    if page.sections:
        lines.append("")
        lines.append("It used to group links under these themes:")
        lines.append("")
        for section in page.sections:
            lines.append(f"- {section}")

    if page.section_notes:
        lines.append("")
        lines.append("Notes that were previously attached to this category:")
        lines.append("")
        for section, note in page.section_notes:
            lines.append(f"- **{section}:** {note}")

    lines.append("")
    lines.append("Use the main [Link Graveyard](/links/) page for search, tag filters, and cross-category browsing.")
    lines.append("")
    lines.append("<!--more-->")
    lines.append("")
    return "\n".join(lines)


def choose_output_path(title: str, link_sections: list[str], used_paths: set[Path], existing: ExistingLeafPage | None) -> Path:
    if existing:
        return existing.path

    base_slug = slugify(title)
    candidate = LINKS_ROOT / f"{base_slug}.md"
    if candidate not in used_paths and not candidate.exists():
        used_paths.add(candidate)
        return candidate

    for link_section in link_sections:
        candidate = LINKS_ROOT / f"{base_slug}-{slugify(link_section)}.md"
        if candidate not in used_paths and not candidate.exists():
            used_paths.add(candidate)
            return candidate

    counter = 2
    while True:
        candidate = LINKS_ROOT / f"{base_slug}-{counter}.md"
        if candidate not in used_paths and not candidate.exists():
            used_paths.add(candidate)
            return candidate
        counter += 1


def assemble_records(existing_pages: dict[str, ExistingLeafPage], legacy_pages: list[LegacyCategoryPage], legacy_links: list[LegacyLink]) -> tuple[list[dict], dict[str, list[LegacyLink]]]:
    merged: dict[str, list[LegacyLink]] = defaultdict(list)
    for item in legacy_links:
        merged[item.url].append(item)

    records: list[dict] = []
    used_paths = {page.path for page in existing_pages.values()}

    for url, items in sorted(merged.items(), key=lambda pair: pair[0]):
        existing = existing_pages.get(url)
        title = choose_title(url, items, existing)
        description = choose_description(items, existing)
        link_sections = sorted({item.category for item in items})
        sections = sorted({item.section for item in items if item.section})
        legacy_sources = sorted({item.source_path for item in items})

        existing_tags = []
        if existing:
            existing_tags = [str(tag) for tag in existing.front_matter.get("tags", []) if str(tag).strip()]
        tags = infer_tags(link_sections[0], sections, title, existing_tags)
        if len(link_sections) > 1:
            for link_section in link_sections[1:]:
                tags = sorted(set(tags) | set(infer_tags(link_section, sections, title, [])))

        existing_link_sections = existing.front_matter.get("link_sections") if existing else None
        if not existing_link_sections and existing:
            existing_link_sections = existing.front_matter.get("categories")
        if existing_link_sections:
            link_sections = sorted({*link_sections, *[str(value) for value in existing_link_sections if str(value).strip()]})

        draft = all(item.source_draft or item.category in DRAFT_CATEGORIES for item in items)
        if existing:
            draft = bool(existing.front_matter.get("draft", draft))
            if not draft:
                draft = False

        dated_candidates = []
        for item in items:
            candidate = git_first_add_date(item.source_path, item.url, item.bullet_text)
            dated_candidates.append(candidate or item.source_date)
        if existing and existing.front_matter.get("date"):
            dated_candidates.append(normalize_date_value(existing.front_matter["date"]))
        dated_candidates = [candidate for candidate in dated_candidates if candidate]
        date = min(dated_candidates) if dated_candidates else "2026-03-03T00:00:00-08:00"

        output_path = choose_output_path(title, link_sections, used_paths, existing)
        body = existing.body if existing else ""
        records.append(
            {
                "title": title,
                "date": date,
                "draft": draft,
                "link_url": url,
                "description": description,
                "link_sections": link_sections,
                "tags": tags,
                "legacy_sections": sections,
                "legacy_source": legacy_sources,
                "output_path": output_path,
                "body": body,
                "existing": existing is not None,
            }
        )

    return records, merged


def write_outputs(records: list[dict], legacy_pages: list[LegacyCategoryPage]) -> None:
    for record in records:
        content = render_leaf_front_matter(record, record["body"])
        record["output_path"].write_text(content)

    for page in legacy_pages:
        front_matter = render_landing_front_matter(page.front_matter)
        new_text = f"+++\n{front_matter}\n+++\n\n{build_category_landing_body(page)}"
        page.path.write_text(new_text)


def write_report(records: list[dict], merged: dict[str, list[LegacyLink]], existing_pages: dict[str, ExistingLeafPage]) -> None:
    total_legacy_links = sum(len(items) for items in merged.values())
    duplicates = {url: items for url, items in merged.items() if len(items) > 1}
    new_files = [record for record in records if not record["existing"]]
    updated_files = [record for record in records if record["existing"]]

    lines = [
        "# Link Migration Report",
        "",
        f"- Total legacy bullets parsed: {total_legacy_links}",
        f"- Unique legacy URLs: {len(merged)}",
        f"- Existing leaf pages reused: {len(updated_files)}",
        f"- New leaf pages to create: {len(new_files)}",
        f"- Duplicate URL merges: {len(duplicates)}",
        "",
        "## Duplicate URL merges",
        "",
    ]

    if duplicates:
        for url, items in sorted(duplicates.items()):
            lines.append(f"### {url}")
            lines.append("")
            for item in items:
                lines.append(f"- `{item.source_path}` -> `{item.title}`")
            lines.append("")
    else:
        lines.append("None.")
        lines.append("")

    lines.append("## Output files")
    lines.append("")
    for record in sorted(records, key=lambda record: record["output_path"].name):
        status = "update" if record["existing"] else "create"
        lines.append(f"- `{status}` `{record['output_path'].relative_to(REPO_ROOT)}`")

    REPORT_PATH.write_text("\n".join(lines) + "\n")


def refresh_existing_leaf_page_dates(existing_pages: dict[str, ExistingLeafPage]) -> list[dict]:
    records: list[dict] = []
    for url, page in sorted(existing_pages.items()):
        front_matter = page.front_matter
        candidate_paths = front_matter_candidate_paths(front_matter)
        resolved_date = git_first_add_date_for_paths(candidate_paths, url)
        existing_date = normalize_date_value(front_matter.get("date", ""))
        best_date = min([value for value in [resolved_date, existing_date] if value]) if (resolved_date or existing_date) else "2026-03-03T00:00:00-08:00"

        record = {
            "title": str(front_matter.get("title", page.path.stem)),
            "date": best_date,
            "draft": bool(front_matter.get("draft", False)),
            "link_url": url,
            "description": normalize_space(str(front_matter.get("description", ""))),
            "link_sections": [
                str(value)
                for value in (
                    front_matter.get("link_sections")
                    or front_matter.get("categories")
                    or []
                )
                if str(value).strip()
            ],
            "tags": [str(value) for value in front_matter.get("tags", []) if str(value).strip()],
            "legacy_sections": [str(value) for value in front_matter.get("legacy_sections", []) if str(value).strip()],
            "legacy_source": candidate_paths[:1] if isinstance(front_matter.get("legacy_source"), str) else [str(value) for value in front_matter.get("legacy_source", []) if str(value).strip()],
            "output_path": page.path,
            "body": page.body,
            "existing": True,
        }
        if not record["legacy_source"]:
            record["legacy_source"] = candidate_paths[:1]
        records.append(record)
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description="Migrate legacy /links markdown lists into individual link pages.")
    parser.add_argument("--write", action="store_true", help="Write migrated leaf pages and rewrite legacy category pages.")
    parser.add_argument("--report", action="store_true", help="Write LINK_MIGRATION_REPORT.md.")
    parser.add_argument("--json", action="store_true", help="Print machine-readable summary.")
    args = parser.parse_args()

    legacy_pages: list[LegacyCategoryPage] = []
    legacy_links: list[LegacyLink] = []
    for path in sorted(LINKS_ROOT.glob("*/index.md")):
        page, links = parse_legacy_category_page(path)
        legacy_pages.append(page)
        legacy_links.extend(links)

    existing_pages = load_existing_leaf_pages()
    if legacy_links:
        records, merged = assemble_records(existing_pages, legacy_pages, legacy_links)
    else:
        records = refresh_existing_leaf_page_dates(existing_pages)
        merged = {}

    summary = {
        "legacy_bullets": len(legacy_links),
        "unique_legacy_urls": len(merged) if merged else len(records),
        "existing_leaf_pages": len(existing_pages),
        "reused_leaf_pages": sum(1 for record in records if record["existing"]),
        "new_leaf_pages": sum(1 for record in records if not record["existing"]),
        "duplicate_url_merges": sorted([url for url, items in merged.items() if len(items) > 1]),
    }

    if args.report:
        write_report(records, merged, existing_pages)

    if args.write:
        write_outputs(records, legacy_pages)

    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print(
            f"Parsed {summary['legacy_bullets']} legacy bullets into {summary['unique_legacy_urls']} unique URLs. "
            f"Reusing {summary['reused_leaf_pages']} existing leaf pages and creating {summary['new_leaf_pages']} new ones."
        )
        if summary["duplicate_url_merges"]:
            print("Duplicate URL merges:")
            for url in summary["duplicate_url_merges"]:
                print(f"- {url}")


if __name__ == "__main__":
    main()
