# Import content cache

The content cache preserves translations and reusable cooked posts across v1
imports. It uses the v2 `disco` CLI and SQLite infrastructure. V2 import support
is deferred until original IDs are persisted in the site database.

## Usage

Enable both optional gem groups in environments running generic_bulk with a cache:

```sh
bundle config set --local with 'migrations generic_import'
bundle install
```

Export from the current migration site before replacing it:

```sh
RAILS_ENV=production migrations/bin/disco cache export /shared/content-cache.db
```

Use one cache file per migration project. Export replaces the file only after
successfully completing and checkpointing SQLite; transfer the completed `.db`
file. Keep source content stable during export. Translation generation may keep
running on unchanged content, but work completed after a row is read belongs to
a later export.

On the destination, pause translation jobs and disable `ai_translation_enabled`
before import. Keep generation disabled through restoration and required rebakes.
The restorer refuses to run while that setting is enabled; it does not stop
already running workers or change the setting itself.

```sh
CONTENT_CACHE=/shared/content-cache.db RAILS_ENV=production \
  bundle exec ruby script/bulk_import/generic_bulk.rb /shared/intermediate.db
```

The optional `CONTENT_CACHE` path enables restoration in `execute_after`, after
category-about topics and entity mappings exist. Without it, the importer uses
its existing behavior. Run the usual consistency tasks, then use selective
rebaking so cached hits are retained:

```sh
RAILS_ENV=production bin/rake import:ensure_consistency
RAILS_ENV=production bin/rake posts:rebake_uncooked_posts
```

Finish queued post/localization processing before creating the release backup
and re-enabling translation generation. Do not run `posts:rebake`, which resets
baked markers for every post and defeats cooked reuse.

Restoration can also be retried independently:

```sh
RAILS_ENV=production migrations/bin/disco cache restore /shared/content-cache.db
```

Both commands print counts for exported/restored content, cache misses, cooked
hits/fallbacks, rewritten fields, stale translations, and ambiguous mappings.
Repeated restoration preserves existing current translations.

## Matching and restoration

Post entries are keyed by the `import_id` custom field and SHA-256 of exact final
stored raw. IDs remain strings; matching never uses destination post IDs or raw
alone. Importer/converter changes, including resolved links in raw, cause misses.
Duplicate or empty mappings are excluded and counted.

Topic entries use their own `import_id` and a fingerprint of source title,
excerpt, and first-post raw. Restoring a matching first post finalizes its source
excerpt before topic matching. Translated excerpts are finalized from restored
first-post translations when available.

Post translations with an old source `post_version` are excluded during export.
Restored translations use the destination post version and newly allocated IDs.
Source locales are preserved unless they conflict with an existing destination
locale. AI system attribution maps to the system user; human attribution maps
through user `import_id`. Unmapped localizers are skipped and reported.

Topic translations have no source-version field: the exporter assumes those rows
are current. Likewise, direct SQL edits that bypass version increments cannot be
identified retrospectively. The generic_bulk integration captures existing source
fingerprints before import and removes translations whose source changes,
including manual translations, so old rows do not suppress backfill. This change
tracking applies within that import run; the standalone restore command cannot
reconstruct earlier edits. It preserves existing topic translations and current
post translations.

## URL replacement and cooked reuse

The cache records source site, CDN, upload storage, and local upload URL bases,
including protocol-relative forms. Original text stays intact in SQLite; fields
containing those bases are earmarked for rewriting on restore. Equal bases leave
text unchanged. Rewriting uses exact prefix boundaries, prefers the longest
matching prefix, and does not cascade replacements. Missing or ambiguous mappings
are reported rather than guessed.

HTML rewriting changes URL attributes and srcset, leaving visible text unchanged.
Translated raw URL rewriting preserves fenced/inline code and HTML code blocks.
Changed URL paths are not semantic ID remapping: final raw hashes already catch
references that changed during import.

Original cooked reuse additionally requires the same Discourse revision, baked
version, settings fingerprint, plugin versions, and per-post cooking context.
The settings fingerprint is deliberately conservative: even some unrelated
setting changes can cause cooked misses. Translation text remains reusable.

The initial HTML allowlist covers simple paragraphs, formatting, lists, headings,
code without rendering-specific attributes, and plain links. Attachment links
also compare referenced upload SHA-1s and resolved URLs; matching raw alone is
insufficient for those dependencies. Images, oneboxes, mentions, quotes with
metadata, polls, and other dynamic markup fall back to processing. This avoids
copying generated destination IDs or optimized asset references without validation.

Cooked hits rebuild upload references, topic links, quoted-post records, and
first-post caches. Translation fallbacks recook stored translated raw locally and
run localized post-processing; they never invoke translation APIs. Missing short
URL uploads cause the affected translation to be skipped. The cache does not
transfer upload files or optimized images.

## Tests

The suites cover:

- Standalone SQLite transfer, exact keys, missing/unsupported files, and failed
  exports retaining the previous artifact.
- Changed destination IDs/versions, changed raw/identity, ambiguous mappings,
  stale source versions, source locales, multiple locales, human attribution,
  existing edits, repeat restoration, and source-change invalidation.
- Independent topic matching and first-post excerpts.
- Changed site/upload URL bases, overlapping bases, host boundaries, ambiguity,
  unchanged bytes, srcset, Markdown destinations, code, and external query values.
- Upload dependency changes, rendering changes, and dynamic HTML fallback.
- CLI usage/required paths and the generic_bulk post-import hook.

```sh
cd migrations/core
bundle exec rspec spec/lib/migrations/content_cache/store_spec.rb

cd ../importer
BUNDLE_WITH=migrations BUNDLE_GEMFILE=../../Gemfile MIGRATIONS_RAILS=1 \
  bundle exec rspec spec/lib/migrations/importer/content_cache_spec.rb \
  spec/lib/migrations/importer/content_cache_urls_spec.rb \
  spec/lib/migrations/importer/cli/cache_command_spec.rb

cd ../..
RAILS_ENV=test BUNDLE_WITH=migrations:generic_import \
  bin/rspec spec/script/bulk_import/generic_bulk_spec.rb
```
