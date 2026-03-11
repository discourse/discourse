# Namespace Style Refactor Plan

This branch contains namespace style cleanups that were split out of `mt/refactor-schema-config` to keep that PR focused.

## Current policy

- Remove leading `::` for library and gem constants in `migrations/`.
- Keep leading `::` for top-level app constants such as `::SiteSettings`, `::UploadCreator`, and `::HasSanitizableFields`.
- Remove leading `::` for internal `Migrations` constants.

The app-constant exception is intentional. Names under `Migrations` are likely to overlap with application model and service names, so root qualification there preserves meaning and avoids lookup surprises.

## Rebase checklist

After rebasing this branch on `main`, run:

```bash
rg -n '\b::Migrations\b' migrations -g '*.rb'
rg -n '::(Extralite::Blob|Extralite::Database|Oj|LruRedux::Cache|EXIFR|ProgressBar)\b' migrations -g '*.rb'
rg -n '^(module|class) Migrations::' migrations/lib migrations/spec migrations/bin migrations/config -g '*.rb'
bin/lint --recent
```

Treat any new `::Migrations` or library-root-qualified constants as drift and clean them up.

## Why nested modules

`module Migrations::Importer` does not put `Migrations` into `Module.nesting`.

Nested form:

```ruby
module Migrations
  module Importer
  end
end
```

does put `Migrations` into lexical nesting. That makes sibling and parent namespace constant lookup work naturally and reduces the need for explicit `Migrations::...` references.

This is the main long-term fix for the constant-qualification noise in `migrations/`.

## Scope and sequencing

There are currently many compact namespace definitions under `migrations/`, so this should be done as a dedicated refactor, not folded into feature work.

Recommended sequence:

1. Convert one subtree at a time from compact namespace definitions to nested modules.
2. In a follow-up commit, shorten internal constant references only where lexical nesting now makes that safe.
3. Keep top-level app constants root-qualified throughout.
4. Verify each subtree before moving to the next one.

Good early targets:

- `migrations/lib/database/schema/dsl`
- `migrations/lib/converters/base`
- `migrations/lib/importer/name_finder`

Avoid hand-editing generated `migrations/lib/database/intermediate_db` files. Change the writers first, then regenerate.

## Plan for shortening `Migrations::...` references

Do not do a repo-wide search-and-replace.

Shorten a reference only when the target constant is available from the current lexical nesting after the nested-module conversion.

Examples:

- Keep qualification when crossing namespace boundaries.
- Keep qualification when a shorter name could resolve to an app constant instead of a `Migrations` constant.
- Keep root qualification for app constants that intentionally escape `Migrations`.

Preferred workflow for each subtree:

1. Convert compact definitions to nested definitions.
2. Run focused tests without shortening references yet.
3. Shorten only the references in that subtree that are now covered by lexical nesting.
4. Run focused tests again.
5. Run one realistic integration path for that area.

Suggested verification commands:

```bash
bin/rspec path/to/subtree_specs
migrations/bin/cli schema generate
bin/lint path/to/changed/files
```

## Safety checks

Use grep to review shortened references before and after each subtree refactor:

```bash
rg -n '^(module|class) Migrations::' migrations/lib migrations/spec migrations/bin migrations/config -g '*.rb'
rg -n '\bMigrations::[A-Z][A-Za-z0-9_:]*' migrations/lib migrations/spec migrations/bin migrations/config -g '*.rb'
```

The goal is not to remove every explicit namespace. The goal is to remove the ones that become redundant after lexical nesting is restored.
