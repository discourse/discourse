# Discourse Blog

A lightweight, server-rendered blog backed by Discourse topics. Write and revise in
Discuss; read articles on a dedicated blog hostname; reply in a deferred, interactive
Discourse discussion below each article.

## Features

- Exactly one configured public Blog category; subcategories are not included.
- Separate editorial-only drafts category and native Discourse composer autosave.
- Editorial dashboard with server-side status filtering, title/path search, and
  pages of 20 that load as you scroll.
- An editor-only publication panel on the article's own topic: state, one-click
  publish or correction, an inline summary and diff of pending changes, inline
  article settings, and scheduling, approval, and withdrawal behind a menu.
  Public discussion topics show a thin banner pointing at the private working copy.
- Authenticated blog-layout preview.
- Explicit revision submission, approval, publication, scheduling, and withdrawal.
- Revocable seven-day draft review links with frozen article revisions and private,
  account-free FormKit feedback. Feedback is never published as topic replies; it
  is counted and readable inline in the working copy's publication panel.
- Private working topics, frozen approved revisions, and preserved public discussions.
- Durable paths, including historical date-based paths; automatic 301 aliases when
  changing an article path. Topic title edits never change the published path.
  Imported paths retain case, plus signs, underscores, dots, commas, and encoded
  plus/comma characters. Dated `/blog/archive/YYYY/MM/DD/...` paths are supported;
  other editorial and asset paths remain reserved. Paths cannot contain queries,
  fragments, traversal segments, or encoded separators.
- Legacy `/posts` redirects permanently to `/`; `/posts.rss` and `/posts.atom`
  redirect permanently to the RSS feed at `/feed.xml`. Article discussions retain
  both the `#discussion` and `#comments` fragment targets.
- Excerpts, featured articles, author bylines, reading time, publication/updated
  dates, and card/social images from the topic's first image upload.
- Paginated homepage, searchable archive (titles/excerpts), public tag pages, and
  Markdown About page.
- RSS with stable item identifiers, sitemap, robots, social metadata, and
  `BlogPosting` structured data.
- Blog-primary canonical for the discussion landing page; later discussion pages
  keep their page-specific canonical.
- A configurable paper/ink/accent palette, graphic covers, and Liquid-based
  designs, with bundled Editorial-style and minimal-reference examples under
  `branding/`.
- Separate Settings, Themes, and Identity pages, with focused FormKit editors for named theme drafts, Git imports,
  syntax-highlighted CSS/JavaScript editors, expiring blog-origin previews, and explicit
  activation of immutable snapshots. Editing or pulling a draft never changes readers.
- Automatic light/dark mode, responsive layouts, and a custom-code safe mode.
- The article requires no Ember boot. Full-app discussion loads near the comments.

## Installation

The plugin is bundled with Discourse as `plugins/blog`. Until launch its enabled
setting is hidden, so it can only be turned on from the Rails console (step 5).

1. Make sure migrations have run; they create the plugin's tables on every site.
2. Route both HTTPS hostnames to the same Discourse installation/database. Keep
   Discuss as the primary/canonical Discourse hostname. On multisite deployments,
   register the blog hostname as an alias in the database connection's `host_names`
   configuration so the correct database is selected before the plugin runs. The
   plugin preserves its configured hostname after database selection; single-site
   deployments do not need a database hostname alias. DNS/TLS/proxy configuration
   must still preserve the original `Host` header. Do not disable hostname checking
   or forward arbitrary untrusted host headers.
3. Create one public **Blog** category. Suggested permissions: everyone can **See
   / Reply**, staff can **See / Reply / Create**. In Ruby these are `:create_post`
   and `:full`, respectively. Replies must be permitted for the audience you want
   to participate.
4. Create a separate **Blog editorial** category, granting access only to the staff,
   admins, and/or moderators automatic groups. A category open to any other group
   is rejected as the drafts category. Use a different category from core's shared
   drafts feature. Do not use the Blog category's description
   topic as an article.
5. Configure:
   - `blog_url`: e.g. `https://blog.example.com`, no trailing slash/path.
   - `blog_category`: the single public category.
   - `blog_drafts_category`: the private editorial category.
   - `blog_title`, `blog_description`, `blog_about`.
   - `blog_enabled`: enable after configuration. The setting is hidden
     for now, so set it from the Rails console:
     `SiteSetting.blog_enabled = true`.
6. In **Admin → Customize → Embedding**, add the exact blog hostname. Enable
   `embed_full_app` and `embed_full_app_signin_flow`. Do not enable embedding from
   every origin merely to make this plugin work.
7. Visit `/blog/editor` on Discuss and create your first draft.

In production, also make sure a proxy's existing `/robots.txt` or `/sitemap.xml`
handlers do not override the blog routes.

### Local hostnames

The blog and Discuss must be the same site: the same scheme and the same
registrable domain, such as `blog.example.com` and `forum.example.com`. Otherwise
the embedded discussion does not receive the Discuss session cookie, and readers
appear signed out in the comments.

Locally, `*.localhost` names reach the Rails server without DNS or hosts-file
changes, and two of them are the same site when they share a parent, for example
`community.dev.localhost` and `blog.dev.localhost`. Environment overrides set the
hostnames for a single run without changing the database. While an override is
set, that setting is hidden in the admin UI.

The simplest setup uses plain HTTP on the Rails port:

```sh
DISCOURSE_FORCE_HOSTNAME=community.dev.localhost \
DISCOURSE_BLOG_URL=http://blog.dev.localhost:3000 \
DISCOURSE_CONTENT_SECURITY_POLICY_FRAME_ANCESTORS=false \
bin/dev
```

The environment override skips the setting's `https://` validation. Frame-ancestors
protection is turned off because core only allows `https://` embedding hosts to
frame Discuss, which would otherwise block the discussion. Add
`blog.dev.localhost:3000` as an embedding host, then sign in at
`http://community.dev.localhost:3000`.

To test closer to production, put a local TLS proxy such as Caddy in front of Rails
for both hostnames and run with `DISCOURSE_FORCE_HTTPS=1`, `DISCOURSE_PORT` set to
the proxy's HTTPS port, and an `https://` blog URL on that port. On macOS, use a
port above 1024 (for example 8443) if the proxy only listens on `127.0.0.1`;
unprivileged processes cannot bind ports below 1024 to a single interface. The
embedding host then includes that port, for example `blog.dev.localhost:8443`.

### Backups and hostname changes

Back up uploads as well as the database. Enable `include_thumbnails_in_backups`
when preserving published revisions: their frozen HTML can reference optimized
images that are not regenerated simply by rendering the article.

A backup carries blog settings, themes, publications, and revisions, but not plugin
source, DNS, TLS, or reverse-proxy configuration. Restore onto a compatible
Discourse build with this plugin installed. Before exposing a restored site, set
the correct blog origin and exact embedding host, and verify both reader and
editorial permissions.

For a hostname-changing restore, also remap absolute URLs inside
`blog_revisions.data`. These snapshots use JSONB; core's text-column
hostname remapping does not update them. Perform this as an explicit, backed-up
restore operation, not by republishing or rebaking live articles. Verify canonicals,
feeds, sitemap, article images, and embedded discussions before reopening traffic.

### Local demo provisioning

```sh
bin/rake blog:demo
```

Development only. Configures the local origin, categories, and embedding, then
adds three sample articles, a private draft, and labeled sample conversations from
the first admin and two random existing users. Articles and replies that already
exist are skipped, so it is safe to re-run; re-running resets the demo site
settings but does not replace existing article bodies. It never runs automatically
during plugin installation or migration.

## Appearance and custom code

Open **Admin → Plugins → Blog**. **Themes** lists the saved designs and the one
currently shown to readers; **Identity** holds the blog name, tagline, and About
content. A design owns its whole look: palette, CSS, JavaScript, and Liquid
templates. Design and color changes are blog-only; they do not restyle Discuss.

Theme cards use a shared typographic specimen and the saved draft's paper, ink,
and accent colors. These covers are palette samples, not screenshots: they do not
load a draft's CSS, fonts, JavaScript, or templates into the admin page. Use the
card's **Preview** action to see the complete rendered design.

The template editor uses FormKit's custom-control slot with Ace bound directly to
`field.value` and `field.set`. Variable insertion changes the field programmatically;
the stock code control captures only its initial value. Keep this binding local to
the template editor rather than patching core or remounting Ace after insertion.
CSS and JavaScript fields use the stock code control.

Reader pages always load one built-in stylesheet, `blog.css`, which is a plain
reading layout, followed by the active design's CSS. The bundled design under
`branding/discourse-blog` shows a richer layout built on that base.

Each theme draft carries its palette, Liquid templates, and two
syntax-highlighted code editors:

- **Custom CSS** loads after the built-in theme. It applies to reader pages and
  authenticated blog-layout previews. Use plain CSS, not SCSS or style tags.
  It cannot cross the discussion iframe boundary; that surface is tinted with the
  design's palette instead. Further discussion styling belongs in a forum theme,
  scoped to `html.discourse-blog-discussion body.embed-mode`.
- **Custom JavaScript** runs deferred, after the document is parsed, on blog-origin
  pages. It is served as a JavaScript file, so `<script>` markup would be a syntax
  error. To load another script, append the element instead:

  ```js
  const script = document.createElement("script");
  script.src = "https://example.com/widget.js";
  document.head.append(script);
  ```

  The file loads with a CSP nonce and the blog's policy uses `strict-dynamic`, so a
  script it appends runs without allowlisting that origin. The code deliberately does
  **not** run in authenticated previews on the Discuss origin, in normal Discuss
  pages, or inside the cross-origin discussion iframe.

Both are administrator-only and publicly downloadable. They are executable/trusted
customizations, not a place for secrets. Saves go through the theme editor and then
through explicit activation, and are audited in staff action logs.
Each code field is limited to 65,536 characters. Invalid CSS/JavaScript is not
silently repaired: test your code before deploying it to readers.

**Recovery:** open a blog URL with `?blog_safe_mode=1` to skip both custom snippets
for that view. The Identity page links to the blog and to that recovery view, and
remains on the separate Discuss hostname even if a customization breaks the blog.
Clear the relevant code field in the theme editor, save the draft, and activate it
to remove a customization. The built-in theme still loads in safe mode. CSS and
JavaScript assets are uncached so a reload picks up saved changes.

Stable styling hooks include `.blog`, `.blog__header`, `.blog__brand`,
`.blog__intro`, `.blog-card`, `.blog-article`, `.blog-article__body`, and
`.blog-discussion`. The body exposes `data-blog-page`.
The palette exposes `--blog-accent-color`, `--blog-paper-color`, and
`--blog-ink-color`. Both themes also expose `--blog-canvas`,
`--blog-foreground`, `--blog-muted`, `--blog-rule`, and `--blog-link-color`.

```css
.blog-article__body {
  font-size: 1.2rem;
}
```

```js
const brand = document.querySelector(".blog__brand");
brand?.setAttribute("title", "Written in our community");
```

The unbranded demo setup includes small, editable CSS/JS examples to demonstrate that the
customization pipeline is active. Article cover uploads take precedence over a
design's decorative graphic covers.

## Reader templates

Reader pages use Liquid templates with optional per-theme overrides. Switch themes
through the normal preview/activation interface; no articles or editorial data need
to change.

## Editorial workflow

1. **New draft** opens the native composer in the private drafts category. Saving
   the topic does not publish it. Internal replies stay on this private topic.
2. Every draft topic shows an editor-only **publication panel** above the first
   post. It states whether the article is a draft, live, live with pending
   changes, scheduled, or unpublished, and offers one primary action.
3. For an existing public article, the public discussion topic shows a banner
   with **Edit privately**, which creates a private working copy and links to it.
   The existing public discussion and its replies keep their IDs.
4. **Article settings** (path, excerpt, date, featured) are edited inline in the
   panel. **Save settings** stages metadata without changing the live article.
5. **Publish** (or **Publish correction** once live) requires confirmation and
   freezes the current draft and settings as a revision, approves it, and copies
   only that frozen article into a separate public discussion (or updates its
   existing first post). It never moves an editorial topic or copies its replies.
   Contributors and editors see **Submit for approval** instead; a publisher then
   previews the submitted revision and chooses **Approve and publish**.
   Publishers may approve their own work.
6. When a live article's working copy drifts, the panel lists which fields
   changed and can show an inline diff against the live revision. While the
   working copy matches the live article there is nothing to publish, so the
   panel offers only **Options → Unpublish**.
7. The panel menu holds the rarer paths: **Schedule…** freezes the draft as it is
   now and releases it at a local date/time; later edits do not change that
   scheduled release unless it is cancelled and rescheduled. The article's optional
   backdated publication date is separate from its scheduled release time.
   **Submit for approval** is also available to publishers who want a second
   sign-off.
8. **Unpublish** withdraws the blog page and cancels scheduling but leaves the
   public discussion accessible. The legacy return-to-drafts endpoint now has the
   same withdrawal semantics and prepares a private working copy; it never moves
   an existing public discussion.

Old paths become redirects only when their replacement revision is published.
Configure the contributor, editor, and publisher group settings alongside native
category permissions: every group with access to the drafts category must also be
in one of the three group settings, or the drafts category is rejected.

## Privacy and security

- Editorial role, ownership where applicable, and topic visibility are checked server-side.
  Personal messages and topics outside the two configured categories cannot be
  published with this interface.
- The public blog always evaluates **anonymous** visibility, even when an editor
  is signed in. Publication alone cannot expose a restricted, unlisted, deleted,
  or hidden source. The first post must also be visible and regular.
- Articles, listings, feed, sitemap, redirects, and topic canonicals use the same
  publication visibility query. A topic moved out of the Blog category disappears
  from the blog; it can become available again if restored while still published.
- Public responses use `private, no-store` in v1 so visibility revocation takes
  effect on the next request. Do not add a CDN cache without a purge/revocation
  design. Already delivered pages, feeds, screenshots, and search copies cannot
  be recalled.
- Preview is authenticated on Discuss, `noindex` and `no-store`; it does not change
  Guardian permissions or enable anonymous share tokens.
- **Secure uploads, login-required sites, and sites that prohibit anonymous file
  downloads are unsupported in this version.**
  Draft text is private, but upload URLs are not access-controlled when secure
  uploads are disabled. Do not put confidential attachments into these drafts.
  Supporting private draft media needs an explicit media-publication design.
- Discourse authentication remains on Discuss. No API key is exposed to the blog
  browser and cookies are not broadened to the parent domain.

## Rendering and discussion scope

Ordinary cooked Markdown/HTML, images, links, tables, quotes, code blocks, native
`details`, and normal media are server rendered. Internal links and media URLs are
made absolute. The stylesheet intentionally does not import the entire Discourse
theme or application bundle.

Onebox layout lives in the shared `public/blog.css`, not in individual designs.
Keep avatars small, ordinary thumbnails beside the text, and explicitly full-size
media on their own row. When changing these rules, check bare `.thumbnail` images,
`.onebox-avatar`, `.aspect-image` wrappers, and `.aspect-image-full-size` wrappers
at narrow and desktop widths in both color modes. Article images outside oneboxes
must retain their normal sizing. Code oneboxes normalize whitespace around their
line lists, preserving it only inside each line. Check line numbering, indentation,
empty lines, and horizontal scrolling without applying article-list spacing.

Syntax highlighting is progressive enhancement in the shared reader. Only articles
with eligible code blocks load the minified core module and the site's existing
language bundle, asynchronously during an idle period (with a timer fallback).
The core module is served locally from the installed frontend assets at a
content-addressed URL; no third-party CDN or Ember application is loaded.
`highlighted_languages` controls available grammars, and `autohighlight_all_code`
controls unlabelled blocks. Explicit `lang-auto` blocks use bounded detection.
Plain-text, opted-out, already highlighted, unknown-language, and oversized
blocks remain readable without decoration. Numbered code oneboxes retain their
line lists, blank lines, and multiline token context. Syntax colors reuse the
site's light/dark palette. Network failures leave the original code intact.

Run the standalone reader checks from the repository root with
`node --test plugins/blog/test/browser/*.test.mjs`. The highlighting
checks use the repository's Playwright Chromium installation and exercise actual
minified modules, CSP, cross-origin language loading, and DOM preservation.

Complex cooked-content widgets (poll interaction, client-side math, galleries,
and arbitrary plugin decorators) are not a complete match
for the full topic renderer yet. The article links to Discuss for that experience.
The full discussion does use the existing Discourse application and its features.

The embed is deferred, not weightless: interaction loads Discourse. It currently
waits for a trusted, post-render readiness message before revealing the iframe,
so the initial unstyled document does not flash against the blog. Script failures
or a 30-second readiness timeout show an accessible fallback instead of leaving
a blank frame. It uses a plugin-managed content-resizing iframe (280px minimum, no maximum height). The iframe expands with its content, including live changes, rather than
creating a second scrolling region. The embedded conversation uses the configured
paper, ink, and accent colors of the active design, which the blog sends to the
frame, with dark-mode support. Styles are scoped
to `html.discourse-blog-discussion body.embed-mode`; ordinary forum pages and
other embeds are unchanged. Historical small-action rows, the topic map, progress counters, redundant topic
footer actions, and development overlays are hidden in this reading view; the full history remains in Discuss.

Existing login, composer, live
updates, moderation, and closed-topic behavior are reused. An **Open in Discuss**
link always remains available. Same-site HTTPS subdomains are the intended v1
setup; unrelated domains and browser storage restrictions need separate testing.

The sitemap currently contains at most 50,000 article entries; very large archives
need a paginated sitemap index before deployment. There is no WordPress importer,
newsletter, subscription system, page builder, or multilingual publishing in this
iteration.

## Development and tests

```sh
bin/rake db:migrate
LOAD_PLUGINS=1 RAILS_ENV=test bin/rake db:migrate
bin/rspec plugins/blog/spec/
bin/qunit --target blog
pnpm exec playwright install chromium --only-shell
node --test plugins/blog/test/browser/*.test.mjs
```

The browser tests require the Chromium headless shell matching the installed
Playwright version. Re-run the install command after updating Playwright.
The reader's syntax-highlighting module and its license are packaged in
`vendor/highlightjs/` inside the plugin, so production does not require
`node_modules` or a modified core asset-copy script. The browser tests exercise
that packaged module against core's language registrations. See
[`vendor/highlightjs/README.md`](vendor/highlightjs/README.md) when updating it.

Core's linters cover the plugin (`bin/lint --fix plugins/blog`), with `vendor/`
excluded from ESLint. As a bundled plugin, its tables are part of core's
`db/structure.sql` and model annotations, so regenerate those after adding a
migration (`bin/rake db:dump_structure`, `bin/rake annotate:clean`).

### Runtime lifecycle safeguards

The plugin packages its reader highlighter independently of core runtime assets.
Regression request tests run without core's vendored asset directory, and browser
tests use the packaged module rather than a development dependency copy.

Review snapshots retain upload references independently of the working draft.
Revocation and hard deletion release those references immediately; an hourly job
releases references for expired reviews, even when the blog is disabled. The
upgrade migration backfills original, optimized, and short-URL upload references for
existing active snapshots. Run migrations before enabling upload cleanup after an upgrade.
Already-deleted uploads cannot be recovered by the migration.

Sites with `prevent_anons_from_downloading_files` enabled are unsupported, alongside
login-required sites and secure uploads. Public blog and review requests fail
closed, publication/review creation is blocked, and the editorial dashboard shows
an actionable configuration error. The plugin never bypasses upload permissions.

## Compact articles in the forum

Published articles of at least 250 words receive a compact first-post presentation
when viewed as forum topics: the editorial excerpt, a link to the blog, and an
**Expand article here** button. The same button can collapse the article again.
Expansion yields the original cooked-content renderer, preserving code, images,
links, decorators, and normal quoting behavior. Expansion state is retained in the
post's decorator state while its component lives.

The complete raw/cooked post is never replaced or truncated. Short announcements,
unpublished topics, private drafts, blog-layout previews, and embedded discussion
rendering are unchanged. Search/context URLs and article-heading fragment links
show the complete post directly. The existing blog-primary canonical is unchanged.
The presentation uses the `post-content-cooked-html` wrapper outlet; themes can
style `.blog-post-summary` without reaching into cooked article content.

## Finding articles in the editor

`/blog/editor` does not download the whole library. It fetches 20 results at a
time and loads the next page as you scroll near the end of the list, while another
page exists.

The All articles, Drafts, Published, and Not on the blog filters run on the server
before pagination. Not on the blog means discussions in the public publication
category which are not currently live articles; private drafts have their own
filter. Search matches titles, slugs, and stored article paths case-insensitively,
across the entire authorized editorial collection, not just downloaded entries.
Search and status apply to every page that loads and are kept in the URL, so a
filtered view survives a reload; changing either starts at the first page. Search input is bounded to 100 characters and SQL wildcards are
escaped. Ordering uses update time and ID, with duplicate rows suppressed when
appending pages if entries move between requests.

The publication panel's settings and schedule forms, theme editor, identity form, and editor search use FormKit. Article
path and excerpt use `@format="full"`, rather than custom input-width CSS. The
public archive's lightweight GET search remains semantic server-rendered HTML;
booting Ember/FormKit there would defeat the no-application-required reader page.

### Theme import and export

The Themes page supports importing a public HTTPS Git repository or a blog theme ZIP
(up to 2 MB and 1,000 archive entries). Both create a new, inactive draft. Export in
the theme editor downloads the **last saved draft**, not unsaved edits or the active
snapshot. Save changes before exporting.

Exports use the same version-2 source layout as Git imports:

- `blog-theme.json`: `version`, `name`, `accent_color`, `paper_color`, `ink_color`
- `blog.css` and `blog.js`
- `templates/{layout,index,article,about,not_found}.liquid`

Empty template files retain the built-in fallback. Archives may contain these files
at the root or inside one enclosing directory. Import applies the same per-file size
and template validation as Git imports; archive contents are never extracted to disk.
Theme IDs, revisions, Git source metadata, activation state, and site identity settings
are not exported. An imported ZIP is an independent draft with no Git connection.
Core Discourse forum theme ZIPs use a different format and cannot be imported here.
