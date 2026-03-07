# Copilot Instructions

This is a Hugo static site (personal website) using the Ryder theme, Tailwind CSS, and Alpine.js.

## Content Creation

Use Hugo archetypes to create new content:

```bash
# Blog post
hugo new content posts/my-post.md

# Recipe
hugo new content --kind recipe projects/recipes/recipe-name.md

# Link entry (uses links archetype with link_url, description, tags fields)
hugo new content links/my-link-name.md
```

## Link Content

Links live as individual markdown files in `content/links/`. Each link file uses the `links` archetype (`archetypes/links.md`) with this frontmatter:

- `title` - Display name of the link
- `link_url` - The external URL
- `description` - Short description
- `tags` - Array of tags for categorization

**Link ordering convention**: When adding new links, add them to the **top** of any list, not the bottom.

## Key Paths

- Config: `config/_default/hugo.toml`
- Theme: `themes/ryder` (git submodule)
- Layout overrides: `layouts/`
- Content sections: `content/posts/`, `content/projects/`, `content/links/`, `content/consulting/`
