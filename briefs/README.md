# Briefs

Short, focused knowledge documents about topics learned during development.

## What is a brief?

- **Project-independent**: Not tied to this project specifically.
- **Reusable**: Can be referenced across different projects.
- **Markdown-based**: YAML frontmatter for metadata, prose and code for content.

## Structure

Simple briefs are a single `.md` file. Complex ones with supporting files use a folder with a `README.md`.

## Frontmatter fields

| Key | Required | Description |
|-----|----------|-------------|
| `title` | Yes | Title of the brief |
| `description` | Yes | One-line summary |
| `created` | Yes | Creation date (YYYY-MM-DD) |
| `updated` | Yes | Last updated date (YYYY-MM-DD) |
| `tags` | Yes | List of discovery tags |
| `category` | No | General category |
| `author` | No | Author or source |
| `references` | No | External links |

## Guidelines

- Keep examples generic — avoid project-specific paths or tool names.
- One topic per brief.
- Update `updated` whenever you revise content.
