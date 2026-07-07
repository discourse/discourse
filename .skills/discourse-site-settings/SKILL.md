---
name: discourse-site-settings
description: Use when adding, modifying, renaming, or reviewing Discourse site settings in core or plugins. Covers config/site_settings.yml and plugin config/settings.yml, setting names, types, defaults, client exposure, areas, validators, i18n descriptions, category/category_list conventions, category scope dropdowns, access patterns, cache implications, tests, browser verification, and migration handoffs.
---

# Discourse Site Settings

Use this skill before writing or reviewing ordinary Discourse site settings. For upcoming-change
feature flags, also use `discourse-upcoming-changes`. For database migrations that rename or
remove settings, use `discourse-migration`.

## Workflow

1. Find nearby examples with `rg`; avoid reading all of `config/site_settings.yml`.
2. Put core settings in `config/site_settings.yml`; put plugin settings in
   `plugins/<plugin>/config/settings.yml`.
3. Add an i18n description under `en.site_settings.<setting_name>` in the matching
   `config/locales/server.en.yml`.
4. Set `client: true` only when frontend code must read the setting through `siteSettings`.
5. Prefer an `area:` for admin grouping when the setting belongs on a filtered settings page.
6. Access settings as `SiteSetting.setting_name` in Ruby and through `@service siteSettings` in JS.
7. Add a validator when a setting depends on another site setting for correctness.
8. Write focused tests for behavior controlled by the setting, including default behavior.
9. Use Playwright/browser to visit the admin site settings page and verify the setting name and
   i18n description render correctly.

## Naming

- Use a name that describes the behavior, not only the implementation.
- Use the conventional suffix for typed settings:
  - `*_groups` for group lists.
  - `*_categories` for `type: category_list`.
  - `*_category` for `type: category`.
- Avoid `_ids` in public site setting names for category lists even though values are stored as ids.
- For paired settings, prepend the same feature name so admins can recognize the settings as a
  related group.

## Descriptions

- Write descriptions for admins, not developers.
- State the default or safest interpretation when ambiguity is likely.
- Mention privacy/security boundaries that always apply.
- If a setting only matters when another setting has a certain value, say so in the description.
- Keep option names consistent with enum values and admin labels.

## Setting Types

### Category Lists

For new behavior that filters topics or posts by a list of categories, prefer a two-setting pattern
when admins may reasonably want inclusion, exclusion, or subcategory control.

Use:

```yaml
xyz_category_scope:
  type: enum
  default: "public"
  choices:
    - "all"
    - "public"
    - "include"
    - "include_strict"
    - "exclude"
    - "exclude_strict"

xyz_categories:
  type: category_list
  default: ""
```

Semantics:

- `all`: all regular topics.
- `public`: all non-read-restricted regular topics.
- `include`: use `xyz_categories` and their subcategories.
- `include_strict`: use only `xyz_categories`.
- `exclude`: start from all regular topics, then remove `xyz_categories` and their subcategories.
- `exclude_strict`: start from all regular topics, then remove only `xyz_categories`.

Do not make `exclude` mean "public minus selected categories" unless the product requirement
explicitly says that. It is harder to explain and usually surprises admins.

Example from Discourse AI admin dashboard highlights:

```yaml
ai_admin_dashboard_highlights_category_scope:
  type: enum
  default: "public"
  choices:
    - "all"
    - "public"
    - "include"
    - "include_strict"
    - "exclude"
    - "exclude_strict"
  client: false
  area: "ai-features/admin_dashboard"

ai_admin_dashboard_highlights_categories:
  type: category_list
  default: ""
  client: false
  area: "ai-features/admin_dashboard"
```

Recommended description shape:

```yaml
ai_admin_dashboard_highlights_category_scope: "Category scope for AI highlights. 'All' includes every category, 'Public' includes categories available to everyone, 'Include' uses these categories and their subcategories, 'Include strict' uses only these categories, 'Exclude' removes these categories and their subcategories, and 'Exclude strict' removes only these categories. Personal messages are always excluded."
ai_admin_dashboard_highlights_categories: "Categories referenced by the include and exclude AI highlights category scopes. Personal messages are always excluded."
```

Implementation notes:

- Use `Category.subcategory_ids(category_id)` when non-strict modes include descendants.
- Keep `IN (:category_ids)` / `NOT IN (:category_ids)` parameterized; parse category-list values
  to integers before passing them into SQL.
- Handle empty lists explicitly:
  - Empty include means match nothing.
  - Empty exclude means exclude nothing.
- If results are cached, include both the scope and the configured category list in the cache key.
- Test public default, all, include, include strict, exclude, exclude strict, private categories,
  personal messages if topics are involved, and subcategories.

### Enum Settings

- Prefer stable machine values such as `include_strict`; let descriptions/admin labels explain them.
- Keep enum values short, lowercase, and underscore-separated.
- When changing values before merge, update all tests and cache keys. After merge, treat value
  changes as migrations/compatibility work.

### Dependent Settings

- Add a validator when one setting only works if another setting is enabled, configured, or has a
  compatible value.
- Keep dependency enforcement server-side; admin descriptions are not enough.
- Test both the valid and invalid combinations.

## Review Checklist

- Is the default safe for existing sites?
- Is the setting hidden from the client unless JS needs it?
- Does a dependency on another setting need a validator?
- Does the admin description answer the likely "what does this include?" question?
- Is the setting grouped into the right admin area?
- Was the admin settings page checked in the browser so the name and description render correctly?
- Are cache keys or background jobs affected by setting changes?
- Are private categories, personal messages, subcategories, deleted records, and anonymous access
  handled where relevant?
