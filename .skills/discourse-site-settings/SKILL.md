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
- When referencing another site setting, use the `{{setting:setting_name}}` token instead of writing
  the raw setting name or hardcoding the translated label. This lets the admin UI render the
  referenced setting consistently and avoids copy drifting when labels change.
- Keep option names consistent with enum values and admin labels.

## Common Options

- `default`: choose a safe default for existing sites. For upload settings, use the id of the
  seeded upload from `db/fixtures/010_uploads.rb`.
- `min`, `max`, `regex`, and `validator`: enforce value constraints server-side; descriptions and
  frontend affordances are not enough.
- `mandatory_values`: pipe-separated values that must always remain in the setting. Common for
  `group_list` settings that must always include admins/moderators.
- `disallowed_groups`: pipe-separated group ids hidden from group selectors and stripped from API
  updates. This only applies to `group_list` settings.
- `requires_confirmation`: use for risky changes that need an admin confirmation dialog. Valid
  values are `simple`, `simple_on_enable`, and `simple_on_disable`; add matching client i18n under
  `admin.site_settings.requires_confirmation_messages.<setting_name>` when the default copy is not
  specific enough.
- `themeable: true`: only for client-side UI settings that themes may override. Prefer simple types
  such as `bool`, `integer`, `list`, or `enum`; normal `SiteSetting.setting = value` writes are not
  allowed for themeable settings.
- `localizable`: use for public text/content settings that content localization may translate. Use
  a hash for metadata such as `max_length:` and `cooked: true` when localized markdown should be
  cooked.
- `area`: use the filtered admin settings page key when the setting belongs with an existing admin
  workflow.
- `refresh: true`: use when clients should reload after the setting changes.

## Setting Types

Start with the simplest type that matches the admin's mental model:

- `bool`: on/off behavior.
- `integer` / `float`: numeric values; set `min`/`max` where possible.
- `enum`: one value from a fixed set; use `enum: "ClassName"` for reusable translated enums.
- `list`: multiple values from choices; use `list_type: compact` for selector-style UI and
  `list_type: simple` for reorderable item lists.
- `group` / `group_list`: one or many groups; use `mandatory_values` and `disallowed_groups` where
  relevant.
- `category` / `category_list`: one or many categories through the category picker.
- `tag_list`, `emoji_list`, `tag_group_list`, `host_list`, `email`, `username`, `color`, `icon`,
  `upload`, `uploaded_image_list`, and `file_size_restriction`: use when the name describes the
  data shape directly.
- `json_schema` / `objects`: structured settings. Prefer these only when a scalar/list setting is
  not enough, and keep tests around schema validation and serialization.

### Category Lists

Use a plain `type: category_list` when the setting means exactly "these categories". Do not add a
scope enum just because the setting involves categories. For example, user-default settings such as
`default_categories_watching` should stay as a single category list; admins are selecting the
categories to apply, not defining an include/exclude query scope.

```yaml
default_categories_watching:
  type: category_list
  default: ""
  area: "user_defaults"
```

Use the two-setting category-scope pattern only when the feature filters a topic/post result set and
admins may reasonably need all/public/include/exclude choices or subcategory control.

```yaml
xyz_category_scope:
  type: enum
  default: "public"
  enum: "CategoryScopeSiteSetting"
  client: false
  area: "feature-name"

xyz_categories:
  type: category_list
  default: ""
  client: false
  area: "feature-name"
  depends_on:
    - xyz_category_scope
  depends_on_values:
    xyz_category_scope:
      - include
      - include_strict
      - exclude
      - exclude_strict
  depends_behavior: "hidden"
  dependent_setting_display: "inline"
```

Semantics:

- `all`: all regular topics.
- `public`: all non-read-restricted regular topics.
- `include`: use `xyz_categories` and their subcategories.
- `include_strict`: use only `xyz_categories`.
- `exclude`: start from all regular topics, then remove `xyz_categories` and their subcategories.
- `exclude_strict`: start from all regular topics, then remove only `xyz_categories`.

The `CategoryScopeSiteSetting` enum provides translated admin labels for these stored values. Pair
it with `depends_on_values`, `depends_behavior: "hidden"`, and `dependent_setting_display: "inline"`
so the category picker appears under the scope setting only when include/exclude modes need it.

Do not make `exclude` mean "public minus selected categories" unless the product requirement
explicitly says that. It is harder to explain and usually surprises admins.

Example from Discourse AI admin dashboard highlights:

```yaml
ai_admin_dashboard_highlights_category_scope:
  type: enum
  default: "public"
  enum: "CategoryScopeSiteSetting"
  client: false
  area: "ai-features/admin_dashboard"

ai_admin_dashboard_highlights_categories:
  type: category_list
  default: ""
  client: false
  area: "ai-features/admin_dashboard"
  depends_on:
    - ai_admin_dashboard_highlights_category_scope
  depends_on_values:
    ai_admin_dashboard_highlights_category_scope:
      - include
      - include_strict
      - exclude
      - exclude_strict
  depends_behavior: "hidden"
  dependent_setting_display: "inline"
```

Recommended description shape:

```yaml
ai_admin_dashboard_highlights_category_scope: "Choose which categories AI highlights can use. Include and exclude options use {{setting:ai_admin_dashboard_highlights_categories}}. Personal messages are always excluded."
ai_admin_dashboard_highlights_categories: "Categories used when the AI highlights category scope is set to <strong>include</strong> or <strong>exclude</strong>."
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
- `depends_on` without `depends_on_values` is for boolean parent settings.
- Use `depends_on_values` when the parent is an enum/string setting and the dependent only applies
  to specific values.
- Use `depends_behavior: "hidden"` when the dependent setting should be hidden until applicable.
- Use `dependent_setting_display: "inline"` when a hidden dependent belongs visually under its
  parent; save/reset controls are grouped with the parent setting.
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
