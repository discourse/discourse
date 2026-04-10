# Field Configurator Refactoring

## Problem

`field.gjs` (466 lines) owns four concerns at once:

1. **Control lookup** — three parallel data structures (`CUSTOM_CONTROLS` set, `CONTROL_TO_FIELD_TYPE` map, and the template conditional chain) all encode which control maps to which rendering path. They must stay in sync manually.
2. **Shared FormKit shell** — the `<@form.Field>` wrapper with its common args (`@name`, `@title`, `@showTitle`, `@description`, `@type`, `@format`, `@validation`, `@validate`, `@onSet`) is duplicated across branches.
3. **Expression-mode state** — `@tracked expressionMode` in Field (line 104) tracks state that could be derived from `@field.value` inside `ExpressionWrapper`. The same wrapper props (`@expressionMode`, `@field`, `@placeholder`, `@supportsExpression`, `@modeItems`, `@onModeChange`) are repeated at lines 268, 358, and 443. The tracked boolean can desync from the actual value prefix (`=`).
4. **Control-specific value normalization** — `handleUserChange`, `handleTagChange`, and `tagValue` exist because inlined select-kit components have different APIs than the custom configurator components.

The conditional chain in the template (lines 251-464) is a symptom: every new control type requires editing this file, and controls with different wrapping needs (standalone, section, field) are interleaved in a flat if/else chain.

## Design

### Responsibility split

- **Registry** owns dispatch and static shape: renderer component, wrapper kind, FormKit field type.
- **Field** is the public facade: looks up the registry entry, normalizes metadata, delegates to the appropriate wrapper + renderer. Call sites unchanged.
- **Renderers** own domain behavior: whether they render at all, config-specific guards, control-specific value normalization, any special container markup.
- **ExpressionWrapper** owns expression-mode state: derives mode from `@field.value` prefix (`=`) instead of receiving it as a tracked prop from Field.

### Registry module

New file: `lib/workflows/control-registry.js`

```js
const CONTROL_REGISTRY = {
  // standalone: renderer manages its own form integration
  notice:                       { kind: "standalone", renderer: NoticeControl },
  condition_builder:            { kind: "standalone", renderer: ConditionBuilderControl },
  data_table_condition_builder: { kind: "standalone", renderer: DataTableConditionBuilderControl },
  data_table_columns:           { kind: "standalone", renderer: DataTableColumnsControl },

  // standalone: manages own <@form.Field> due to dynamic type switching
  boolean:                  { kind: "standalone",               renderer: BooleanControl },

  // field: wrapped in <@form.Field>
  code:                     { kind: "field", type: "code",      renderer: CodeControl },
  combo_box:                { kind: "field", type: "custom",    renderer: ComboBox },
  credential:               { kind: "field", type: "custom",    renderer: Credential },
  data_table_column_select: { kind: "field", type: "custom",    renderer: DataTableColumnSelect },
  multi_combo_box:          { kind: "field", type: "custom",    renderer: MultiComboBox },
  filter_query:             { kind: "field", type: "custom",    renderer: FilterQuery },
  url_preview:              { kind: "field", type: "custom",    renderer: UrlPreview },
  tags:                     { kind: "field", type: "custom",    renderer: TagsControl },
  category:                 { kind: "field", type: "custom",    renderer: CategoryControl },
  user:                     { kind: "field", type: "custom",    renderer: UserControl },
  user_or_group:            { kind: "field", type: "custom",    renderer: UserOrGroupControl },
  select:                   { kind: "field", type: "select",    renderer: SelectControl },
  icon:                     { kind: "field", type: "icon",      renderer: IconControl },

  // default: fallback for unregistered controls (text, number, etc.)
  default: {
    kind: "field",
    type: ({ inputType }) => `input-${inputType}`,
    renderer: DefaultInputControl,
  },
};
```

The `type` field is either a string literal or a resolver function. Field normalizes it once via a `resolvedFieldType` getter — the template only sees a string.

### Field facade (simplified)

After refactoring, Field's template becomes:

```hbs
<template>
  {{#if (eq this.entry.kind "standalone")}}
    <this.renderer
      @form={{@form}}
      @formApi={{@formApi}}
      @configuration={{@configuration}}
      @connections={{@connections}}
      @fieldName={{@fieldName}}
      @label={{this.fieldTitle}}
      @metadata={{this.metadata}}
      @node={{@node}}
      @nodes={{@nodes}}
      @nodeDefinition={{this.nodeDefinition}}
      @nodeTypes={{@nodeTypes}}
      @schema={{@schema}}
    />
  {{else}}
    <@form.Field
      @name={{@fieldName}}
      @title={{this.fieldTitle}}
      @showTitle={{this.showLabel}}
      @description={{this.fieldDescription}}
      @type={{this.resolvedFieldType}}
      @format={{this.format}}
      @validation={{this.validation}}
      @validate={{this.customValidation}}
      @onSet={{@onSet}}
      as |field|
    >
      <this.renderer
        @field={{field}}
        @fieldName={{@fieldName}}
        @schema={{@schema}}
        @configuration={{@configuration}}
        @metadata={{this.metadata}}
        @nodeDefinition={{this.nodeDefinition}}
        @formApi={{@formApi}}
        @supportsExpression={{this.supportsExpression}}
        @placeholder={{this.placeholder}}
      />
    </@form.Field>
  {{/if}}
</template>
```

Two branches: standalone (renderer manages everything) vs field (Field provides the FormKit shell, renderer handles the interior). This replaces the 15-branch chain.

Field gains:

```js
get entry() {
  return CONTROL_REGISTRY[this.control] || CONTROL_REGISTRY.default;
}

get renderer() {
  return this.entry.renderer;
}

get resolvedFieldType() {
  const { type } = this.entry;
  return typeof type === "function" ? type({ inputType: this.inputType }) : type;
}
```

Field loses: `expressionMode` tracked property, `onModeChange` action, `handleUserChange`, `handleTagChange`, `tagValue`, `fieldType` getter. All move to their respective renderers or ExpressionWrapper.

### ExpressionWrapper changes

ExpressionWrapper derives mode from `@field.value` instead of receiving `@expressionMode`:

```js
get expressionMode() {
  return isExpression(this.args.field?.value);
}
```

It also owns the mode toggle action (currently `onModeChange` in Field). This eliminates the tracked state that can desync from the actual value.

Each `kind: "field"` renderer that supports expressions wraps its content in `<ExpressionWrapper>` internally, rather than Field doing it in the template. This means the expression wrapper props are defined once in ExpressionWrapper's interface, not repeated 3 times in Field's template.

### New thin wrapper components

Four new components wrapping raw select-kit components with a consistent interface:

**TagsControl** — wraps `MiniTagChooser`, owns `tagValue` parsing and `handleTagChange`.

**CategoryControl** — wraps `CategoryChooser`, passes `@field.value` / `@field.set`.

**UserControl** — wraps `UserChooser` with `maximum=1`, owns `handleUserChange` (extracts first username).

**UserOrGroupControl** — wraps `EmailGroupUserChooser` with `maximum=1, includeGroups=true`, owns `handleUserChange`.

### Existing components that become renderers with minimal changes

These already exist and accept `@field` + domain-specific args. They need no structural changes, just need to wrap their output in `<ExpressionWrapper>` if they support expressions:

- `ComboBox` (`combo-box.gjs`)
- `Credential` (`credential.gjs`)
- `DataTableColumnSelect` (`data-table-column-select.gjs`)
- `MultiComboBox` (`multi-combo-box.gjs`)
- `FilterQuery` (`filter-query.gjs`)
- `UrlPreview` (`url-preview.gjs`)

### New renderer components for currently-inlined controls

**NoticeControl** — renders `<@form.Alert @type="info">` with description. Standalone.

**BooleanControl** — owns the toggle/expression duality. When expression mode is active (derived from value), renders expression input via ExpressionWrapper. When plain, renders `<field.Control />` (toggle) with the mode switcher. Boolean needs to switch between `type="toggle"` and `type="custom"` based on expression mode, so Field's single `<@form.Field @type={{this.resolvedFieldType}}>` wrapper can't serve it. Making it `kind: "standalone"` keeps the facade clean and lets BooleanControl own its own `<@form.Field>` wrapper(s).

**CodeControl** — renders `<field.Control @height={{...}} @lang={{...}} />`. Receives `@schema` to extract `ui.height` and `ui.lang`.

**SelectControl** — renders `<field.Control @includeNone={{false}}>` with `<c.Option>` for each choice. Owns option normalization and label lookup.

**IconControl** — renders `<field.Control />` (FormKit's icon type handles everything).

**DefaultInputControl** — renders `<field.Control placeholder={{...}} />`. The simplest renderer.

### Standalone renderers: notice and structural controls

These already exist as components that manage their own form integration:

- **ConditionBuilder** (`condition-builder.gjs`) — used as-is, no changes needed.
- **DataTableConditionBuilder** (`data-table-condition-builder.gjs`) — used as-is, no changes needed.
- **DataTableColumns** (`data-table-columns.gjs`) — used as-is. Self-guards on `@configuration.data_table_id` internally (it already does via `{{#if this.columns.length}}`). The current `{{#if @configuration.data_table_id}}` guard in field.gjs (line 333) moves into the component.

**NoticeControl** is new — extracts the `<@form.Alert>` rendering from field.gjs.

### Call site impact

**Zero changes to call sites.** Field remains the public API. All callers (property-engine.gjs, collection.gjs, condition-builder.gjs, data-table-columns.gjs) pass the same args.

### Args surface

Field passes a superset of args to every renderer. Each renderer uses only what it needs. The full set:

**Standalone renderers receive:** `@form`, `@formApi`, `@configuration`, `@connections`, `@fieldName`, `@label`, `@metadata`, `@node`, `@nodes`, `@nodeDefinition`, `@nodeTypes`, `@schema`

**Field-wrapped renderers receive:** `@field`, `@fieldName`, `@schema`, `@configuration`, `@metadata`, `@nodeDefinition`, `@formApi`, `@supportsExpression`, `@placeholder`

### File inventory

New files:
- `lib/workflows/control-registry.js` — registry module
- `configurators/tags-control.gjs` — wraps MiniTagChooser
- `configurators/category-control.gjs` — wraps CategoryChooser
- `configurators/user-control.gjs` — wraps UserChooser
- `configurators/user-or-group-control.gjs` — wraps EmailGroupUserChooser
- `configurators/boolean-control.gjs` — toggle/expression duality
- `configurators/code-control.gjs` — code editor field
- `configurators/select-control.gjs` — select with options
- `configurators/icon-control.gjs` — icon picker
- `configurators/default-input-control.gjs` — fallback text/number input
- `configurators/notice-control.gjs` — alert/notice display

Modified files:
- `configurators/field.gjs` — gutted and simplified to facade
- `configurators/expression-wrapper.gjs` — owns expression-mode state
- `configurators/combo-box.gjs` — adds ExpressionWrapper internally
- `configurators/credential.gjs` — adds ExpressionWrapper internally
- `configurators/data-table-column-select.gjs` — adds ExpressionWrapper internally
- `configurators/multi-combo-box.gjs` — adds ExpressionWrapper internally
- `configurators/filter-query.gjs` — adds ExpressionWrapper internally
- `configurators/url-preview.gjs` — adds ExpressionWrapper internally
- `configurators/data-table-columns.gjs` — absorbs visibility guard from field.gjs

Unchanged files:
- `configurators/property-engine.gjs` — no changes
- `configurators/collection.gjs` — no changes
- `configurators/condition-builder.gjs` — no changes (already standalone)
- `configurators/data-table-condition-builder.gjs` — no changes (already standalone)
- `configurators/expression-input.gjs` — no changes

## Testing

- Existing integration/system tests should continue to pass since the public API (Field component + its args) is unchanged.
- New renderer components can be tested in isolation by rendering them directly with mock `@field` objects.
- ExpressionWrapper's mode derivation can be tested by passing different `@field.value` values (with/without `=` prefix) and asserting the rendered output.
