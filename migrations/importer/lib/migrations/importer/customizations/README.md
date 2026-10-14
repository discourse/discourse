# Customizations transfer

Moves site customizations (settings, themes, palettes, group and category
looks, translation overrides) from one Discourse site to others. Typical use:
someone customized the migrated site instead of the template site. We find
those changes, put them into one ZIP, and apply each part where it belongs:

- `template`: the template site, applied once.
- `import`: every migrated site, applied after each test migration. Used for
  things that reference imported data and for login/SSO configuration.
- `skip`: not transferred.

## Workflow

```sh
# 1. Find what changed: restore both dumps, then diff them (no Rails needed)
migrations/bin/disco customizations diff \
  --before "dbname=site_before host=/var/run/postgresql" \
  --after "dbname=site_after host=/var/run/postgresql" \
  --json diff.json

# 2. Build a plan, connected to the site the changes live on ("after")
migrations/bin/disco customizations plan --diff diff.json --output plan.yml [--mappings-db mappings.db]

# 3. Review plan.yml, then export the current values from the same site
migrations/bin/disco customizations export --plan plan.yml --output bundle.zip [--upload-base-url https://site]

# 4. Apply, connected to the destination site
migrations/bin/disco customizations apply bundle.zip --target template [--dry-run]
migrations/bin/disco customizations apply bundle.zip --target import --mappings-db mappings.db
```

`diff` fingerprints every table and only diffs the ones that differ, row by
row by primary key. Content and activity tables are skipped by default
(`--include`, `--no-default-skips`); `--where TABLE=SQL` can be repeated to
compare only some rows. Secret values (credential columns, secret-looking
setting/custom field names, settings flagged `secret: true`) are replaced by
`[redacted:…]` tags while reading, so they never reach the report. Equal values
get equal tags within one run.

`apply` compares before it writes and only changes what differs, so it is
safe to run again. It prints one line per item (changed, unchanged, skipped,
failed) and exits non-zero if anything failed.

## Plan format

The plan only selects items; values are read from the site at export time.
Items are identified by name or other natural keys, never by database id.
Every item has a `target` and may have a `note`. You can write a plan by hand
when there is no "before" dump to diff against.

```yaml
format_version: 1
site_settings:
  - name: title
    target: template
  - name: logo
    target: template
  - name: invite_only
    reset: true            # back to the default value
    target: template
  - name: openid_connect_client_secret
    target: import
    secret: true
themes:
  - name: My component     # whole theme: code, settings, palettes, children
    target: template
  - name: Horizon
    system_id: -2          # system themes are found by id
    target: template
color_schemes:
  - name: My palette
    target: template
groups:
  - name: staff            # automatic groups by their built-in name
    target: template
    attributes: [flair_bg_color, flair_upload]
  - name: members
    target: import
    match: { original_id: 12, import_id: "12", name: members }
    attributes: [title, primary_group]
categories:
  - name: Announcements
    target: import
    match: { original_id: 3, slug_path: announcements }
    attributes: [color, text_color, uploaded_logo]
translation_overrides:
  - locale: en
    key: js.login.oidc.title
    target: import
```

Only the listed group and category `attributes` are written, so unrelated
fields stay as they are on the destination.

## Finding imported records

Ids differ between test migrations. Imported groups and categories are found
with these strategies, in order:

1. the importer's MappingsDB (`--mappings-db`), via the original id
2. the `import_id` custom field written by the older import scripts
3. the group name or the category slug path (`parent/child`)

On the `import` target, an item that matches nothing is skipped. On the
`template` target, missing groups and categories are created.

## Plan rules

`plan` decides targets with the rules in `plan/rules.rb`:

- Site settings: unknown, themeable and hidden settings are skipped, and so
  are hosting-managed ones (outgoing/incoming email addresses, POP3 polling,
  S3 and backup storage, `force_https`; see `HOSTING_MANAGED_SETTINGS`).
  Settings overridden by a global setting (`DISCOURSE_<NAME>` environment
  variables or `discourse.conf`) are skipped by `plan`, refused by `export`,
  and skipped by `apply` when the destination overrides them.
  Hidden settings changed through admin pages (about page, email appearance,
  robots.txt) are skipped too; add them to the plan by hand if needed. Login
  and SSO settings, secrets, and settings that reference categories, topics,
  users or non-automatic groups go to `import`. The rest goes to `template`.
- Automatic and site-created groups go to `template`, imported ones to `import`.
- Imported categories go to `import`, others to `template`.
  Changed group permissions are added as a `permissions` attribute (group
  names and permission types); a group missing on the destination fails the item.
- Attributes that only changed between NULL and an empty string are ignored.
- Themes and palettes go to `template`. Palettes owned by a theme travel with
  that theme.
- Translation overrides for login providers go to `import`, others to `template`.
- Changes in tables the tool doesn't handle are listed as comments at the end
  of the plan. Review them by hand.

## Bundle contents and secrets

The ZIP holds `manifest.json`, the referenced upload files (`uploads/`) and
the files of local themes (`themes/`). Git themes are stored as repository URL
and branch; private repositories are skipped. Uploads are created on the
destination when they are first needed and reused when the same file exists.

Secret values are not exported unless `--include-secrets` is given. On apply,
a secret without a value is read from `DISCO_SECRET_<SETTING_NAME>`, or asked
for on a terminal, and skipped otherwise.

Theme children are only added on apply, never removed.
