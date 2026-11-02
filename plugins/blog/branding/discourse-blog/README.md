# Discourse Blog

A standalone version-2 reader theme inspired by https://blog.discourse.org/ as
observed on September 9, 2026. It reproduces the lavender background, rounded
white cards, prominent lead story, three-column desktop listing, purple links,
and bold sans-serif headings paired with serif summaries and article text.

The theme keeps this site's identity, approved articles, author names, archive
search, feeds, and native discussion section. It does not copy the reference's
marketing navigation, logo, article images, analytics, or scripts. Author initials
replace avatars because the current Liquid contract does not expose avatar URLs.
A title-based graphic supplies the lead cover when the article has no image.
System fonts avoid additional font downloads and font-related layout shifts.

## Install and edit

A saved draft named **Discourse Blog** is installed on the development site under
**Admin → Plugins → Blog → Themes**. It is not activated automatically. Open its
editor to preview, customize, or activate it independently of existing themes.

For another site, copy `blog-theme.json`, `blog.css`, and `templates/` to the root
of a public Git repository and use **Import from Git**. No build step or JavaScript
is required. Palette fields remain configurable, and the stylesheet uses the
reader's light/dark palette. Layout, homepage/archive, article, About, and
not-found templates are included.

The listing uses real archive search instead of the reference's external search.
Preview search forms retain the signed capability. All page templates preserve
normal pagination, accessible navigation, and the core-owned content/discussion
slot; no publication or permission behavior changes.

## Checks

Request coverage is in `spec/requests/themes_spec.rb` under
"Discourse Blog reference theme". It renders each page through a signed preview,
checks for Liquid diagnostics and the discussion slot, confirms activation is
unchanged, and verifies empty listings and preview-aware search fields.
