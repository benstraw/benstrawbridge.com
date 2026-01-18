#!/usr/bin/env python3
"""
Script to check all links in the Hugo links section.
Extracts markdown links and checks their HTTP status.
"""

import os
import re
import urllib.request
import urllib.error
import json
from pathlib import Path
from urllib.parse import urlparse
import ssl
import socket

# Create SSL context that doesn't verify certificates (some sites have issues)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

def extract_links_from_markdown(content):
    """Extract all URLs from markdown content."""
    links = []

    # Match markdown links: [text](url)
    markdown_pattern = r'\[([^\]]+)\]\(([^\)]+)\)'
    for match in re.finditer(markdown_pattern, content):
        text = match.group(1)
        url = match.group(2)
        # Skip anchor links and relative links
        if url.startswith('http://') or url.startswith('https://'):
            links.append({
                'text': text,
                'url': url
            })

    return links

def check_url_status(url, timeout=10):
    """Check the HTTP status of a URL."""
    try:
        # Add user agent to avoid being blocked
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }

        req = urllib.request.Request(url, headers=headers)

        with urllib.request.urlopen(req, timeout=timeout, context=ssl_context) as response:
            status_code = response.getcode()
            final_url = response.geturl()

            # Check if redirected
            redirected = final_url != url

            return {
                'status': 'success',
                'status_code': status_code,
                'redirected': redirected,
                'final_url': final_url if redirected else None,
                'error': None
            }

    except urllib.error.HTTPError as e:
        return {
            'status': 'http_error',
            'status_code': e.code,
            'redirected': False,
            'final_url': None,
            'error': f'HTTP {e.code}: {e.reason}'
        }

    except urllib.error.URLError as e:
        # Check if it's a timeout or connection error
        if isinstance(e.reason, socket.timeout):
            return {
                'status': 'timeout',
                'status_code': None,
                'redirected': False,
                'final_url': None,
                'error': 'Request timed out'
            }
        else:
            return {
                'status': 'url_error',
                'status_code': None,
                'redirected': False,
                'final_url': None,
                'error': str(e.reason)
            }

    except Exception as e:
        return {
            'status': 'error',
            'status_code': None,
            'redirected': False,
            'final_url': None,
            'error': str(e)
        }

def main():
    links_dir = Path('content/links')
    all_results = {}

    # Find all markdown files
    md_files = list(links_dir.rglob('*.md'))

    print(f"Found {len(md_files)} markdown files in links section\n")

    total_links = 0

    for md_file in sorted(md_files):
        # Skip _index.md files at root
        if md_file.name == '_index.md' and md_file.parent == links_dir:
            continue

        # Read file content
        with open(md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract links
        links = extract_links_from_markdown(content)

        if not links:
            continue

        section_name = md_file.parent.name
        if section_name not in all_results:
            all_results[section_name] = []

        print(f"Checking {len(links)} links in {section_name}...")

        for link in links:
            url = link['url']
            print(f"  Checking: {url[:70]}...")

            result = check_url_status(url)

            all_results[section_name].append({
                'text': link['text'],
                'url': url,
                **result
            })

            total_links += 1

    # Save results to JSON
    with open('link_check_results.json', 'w', encoding='utf-8') as f:
        json.dump(all_results, f, indent=2)

    print(f"\n✓ Checked {total_links} total links")
    print(f"✓ Results saved to link_check_results.json")

    # Generate summary
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)

    success_count = 0
    error_count = 0
    redirect_count = 0
    http_errors = {}

    for section, links in all_results.items():
        for link in links:
            if link['status'] == 'success':
                success_count += 1
                if link['redirected']:
                    redirect_count += 1
            else:
                error_count += 1
                if link['status'] == 'http_error':
                    code = link['status_code']
                    http_errors[code] = http_errors.get(code, 0) + 1

    print(f"\nTotal links checked: {total_links}")
    print(f"✓ Working: {success_count} ({success_count/total_links*100:.1f}%)")
    print(f"  - Redirected: {redirect_count}")
    print(f"✗ Errors: {error_count} ({error_count/total_links*100:.1f}%)")

    if http_errors:
        print("\nHTTP Error breakdown:")
        for code, count in sorted(http_errors.items()):
            print(f"  - {code}: {count} links")

if __name__ == '__main__':
    main()
