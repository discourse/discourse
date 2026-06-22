# Content Patterns

Use this reference for admin page body layout, cards, forms, subheaders, help insets, tables, empty states, and third-level routes.

## Body layout

Wrap page content in the established admin page area class:

```gjs
<div class="admin-config-page__main-area">
  ...
</div>
```

When a page has primary content plus contextual help, use a two-column layout where the primary content takes about two-thirds and the help/reference area takes about one-third. On small screens the columns should stack. If there is no secondary content, keep the main content width consistent with comparable pages instead of expanding into a bespoke full-width layout.

Prefer existing admin classes and nearby page structure before creating new layout CSS.

## DPageSubheader

Use `DPageSubheader` from `discourse/ui-kit/d-page-subheader` to introduce a section below the main page header, especially when the section has a description or action buttons.

Use `h2`-level subheaders through the component, and keep action labels specific. Primary actions use the yielded primary button; secondary actions use default buttons and usually appear only when a primary action exists.

Example to inspect: `plugins/discourse-data-explorer/admin/assets/javascripts/admin/templates/admin-plugins/show/explorer/index.gjs`.

```gjs
<DPageSubheader
  @titleLabel={{i18n "admin.example.records.title"}}
  @descriptionLabel={{i18n "admin.example.records.description"}}
>
  <:actions as |actions|>
    <actions.Primary
      @route="admin.example.records.new"
      @label="admin.example.records.add"
    />
  </:actions>
</DPageSubheader>
```

## Config area cards

Use `AdminConfigAreaCard` from `discourse/admin/components/admin-config-area-card` for grouped settings, setup steps, and form sections. Cards should group related work, put the most important content first, and usually have one primary next action.

Card headings should be sentence-cased. Use `@heading` for I18n keys or `@translatedHeading` when the caller already has translated text.

```gjs
<AdminConfigAreaCard
  @heading="admin.config_areas.example.general_settings"
  class="admin-example__general-settings"
>
  <ExampleSettingsForm @model={{@model}} />
</AdminConfigAreaCard>
```

Current examples:

- `frontend/discourse/admin/templates/admin-embedding/index.gjs`
- `plugins/discourse-ai/admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-ai-features/edit.gjs`

## Forms

Use FormKit for new admin forms. Do not build ad hoc form controls when FormKit components cover the interaction. Keep client validation paired with server-side validation; do not rely only on browser or JS validation.

Reference: `docs/developer-guides/docs/03-code-internals/21-form-kit.md` and `frontend/discourse/app/form-kit`.

New/edit forms usually belong on third-level routes rather than inline inside a table row. This makes the form linkable, reloadable, and easier to test.

## Help insets

Use help/reference content for contextual docs, caveats, or links that help admins complete the task. Keep it in the secondary column and sentence-case headings. Include an icon in the heading when the surrounding pattern does so.

Do not turn help content into marketing copy. It should answer what the admin needs to know at this point in the workflow.

## Tables

Use tables for growing sets of structured records where each row has the same attributes and admins need to scan, edit, enable/disable, or delete entries.

Structural classes:

- `<table class="d-table">`
- `<thead class="d-table__header">`
- `<tbody class="d-table__body">`
- `<tr class="d-table__row">`
- Overview cell: `d-table__cell --overview`
- Detail cell: `d-table__cell --detail`
- Controls cell: `d-table__cell --controls`
- Action wrapper: `d-table__cell-actions`

Overview cells should carry the row identity. When rows have a show/edit page, wrap the main name/description in a `LinkTo` with `d-table__overview-link`, and mark the primary name with `d-table__overview-name`.

Every non-overview cell needs a mobile label matching its header:

```gjs
<td class="d-table__cell --detail">
  <div class="d-table__mobile-label">
    {{i18n "admin.example.status"}}
  </div>
  {{record.status}}
</td>
```

For row actions:

- Put actions in the far-right controls cell.
- If there is one primary action, make it a text button such as Edit.
- If there are multiple secondary/destructive actions, group them in `DMenu` with `DDropdownMenu`.
- Confirm destructive actions before executing them.
- Apply `btn-small` to row action buttons unless the local pattern says otherwise.
- Use `DToggleSwitch` for enable/disable toggles.

Current examples:

- Core table and empty list: `frontend/discourse/admin/templates/admin-permalinks/index.gjs`
- Plugin table: `plugins/discourse-data-explorer/admin/assets/javascripts/admin/templates/admin-plugins/show/explorer/index.gjs`
- Toggle rows: `plugins/discourse-calendar/assets/javascripts/discourse/components/admin-holidays-list-item.gjs`

## Empty lists

When an empty list can be resolved by creating a record, use `AdminConfigAreaEmptyList` with a clear CTA label and route/action.

```gjs
<AdminConfigAreaEmptyList
  @emptyLabel="admin.example.no_records"
  @ctaLabel="admin.example.add_record"
  @ctaRoute="admin.example.records.new"
/>
```

Do not show an empty-list CTA for filtered search results. In that case show a no-results message and a way to clear/reset filters.

## Third-level new/edit routes

Use standalone routes for forms or detailed record editing:

- New: `<resource>/new`
- Edit: `<resource>/:id/edit`

These routes must reload directly from the browser; add matching backend routes when required. Avoid inline forms inside index tables unless the existing page already depends on that pattern.

Third-level new/edit pages should:

- Omit the normal page header, breadcrumbs, and subheader.
- Show a `BackButton` at the top.
- Wrap form content in `AdminConfigAreaCard`.
- Use card headings for form subsections.

```gjs
<BackButton
  @route="adminConfig.flags"
  @label="admin.config_areas.flags.back"
/>

<AdminConfigAreaCard @heading="admin.config_areas.flags.form.title">
  <AdminFlagsForm @model={{@model}} />
</AdminConfigAreaCard>
```

Current examples:

- Thin route template: `frontend/discourse/admin/templates/admin-config/flags/new.gjs`
- Plugin edit card: `plugins/discourse-ai/admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-ai-features/edit.gjs`
