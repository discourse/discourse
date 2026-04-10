# Field Configurator Refactoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose `field.gjs` into a registry-based dispatch with standalone renderer components, moving expression-mode ownership to ExpressionWrapper and eliminating the 15-branch conditional chain.

**Architecture:** A single `CONTROL_REGISTRY` maps control names to `{ kind, type, renderer }` entries. Field remains the public facade with two template branches (standalone vs field-wrapped). Renderers own domain behavior including ExpressionWrapper integration. ExpressionWrapper derives mode from `@field.value`.

**Tech Stack:** Ember/Glimmer components (.gjs), FormKit, Discourse select-kit

---

**Base path for all relative paths:**
`plugins/discourse-workflows/admin/assets/javascripts/admin`

**Test base path:**
`plugins/discourse-workflows/test/javascripts`

**Existing regression test:**
`test/javascripts/integration/components/workflows/property-engine-test.gjs`
— covers text input, collections, condition builder, url preview, icon (with expression mode toggle), select, combo box with metadata.

---

### Task 1: Create select-kit wrapper components

Four thin components that normalize raw select-kit APIs into a consistent interface. Each wraps a select-kit component in ExpressionWrapper.

**Files:**
- Create: `components/workflows/configurators/tags-control.gjs`
- Create: `components/workflows/configurators/category-control.gjs`
- Create: `components/workflows/configurators/user-control.gjs`
- Create: `components/workflows/configurators/user-or-group-control.gjs`

- [ ] **Step 1: Write `tags-control.gjs`**

Extracts `tagValue` helper and `handleTagChange` action from `field.gjs:82-89` and `field.gjs:244-249`.

```js
import Component from "@glimmer/component";
import { action } from "@ember/object";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import ExpressionWrapper from "./expression-wrapper";

function tagValue(value) {
  if (Array.isArray(value)) {
    return value;
  }
  if (typeof value === "string" && value.length > 0) {
    return value.split(",").map((t) => t.trim());
  }
  return [];
}

export default class TagsControl extends Component {
  @action
  handleChange(tags) {
    const names = (tags || []).map((t) =>
      typeof t === "string" ? t : t.name || t.id || t
    );
    this.args.field.set(names);
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <MiniTagChooser
        @value={{tagValue @field.value}}
        @onChange={{this.handleChange}}
      />
    </ExpressionWrapper>
  </template>
}
```

- [ ] **Step 2: Write `category-control.gjs`**

```js
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <CategoryChooser @value={{@field.value}} @onChange={{@field.set}} />
  </ExpressionWrapper>
</template>
```

- [ ] **Step 3: Write `user-control.gjs`**

Extracts `handleUserChange` from `field.gjs:239-241`.

```js
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import UserChooser from "discourse/select-kit/components/user-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class UserControl extends Component {
  @action
  handleChange(usernames) {
    this.args.field.set(usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <UserChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
        @options={{hash maximum=1 excludeCurrentUser=false}}
      />
    </ExpressionWrapper>
  </template>
}
```

- [ ] **Step 4: Write `user-or-group-control.gjs`**

```js
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class UserOrGroupControl extends Component {
  @action
  handleChange(usernames) {
    this.args.field.set(usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <EmailGroupUserChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
        @options={{hash maximum=1 includeGroups=true excludeCurrentUser=false}}
      />
    </ExpressionWrapper>
  </template>
}
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/tags-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/category-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/user-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/user-or-group-control.gjs
git commit -m "feat(workflows): add select-kit wrapper configurator components"
```

---

### Task 2: Create simple renderer components

Four new components for controls currently inlined in Field's template.

**Files:**
- Create: `components/workflows/configurators/notice-control.gjs`
- Create: `components/workflows/configurators/code-control.gjs`
- Create: `components/workflows/configurators/icon-control.gjs`
- Create: `components/workflows/configurators/default-input-control.gjs`

- [ ] **Step 1: Write `notice-control.gjs`**

Standalone renderer. Extracts `field.gjs:252-255`. Computes its own description from schema/nodeDefinition.

```js
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  fieldShowDescription,
  propertyDescription,
} from "../../../lib/workflows/property-engine";

export default class NoticeControl extends Component {
  get description() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    const desc = propertyDescription(this.args.nodeDefinition, this.args.fieldName);
    return desc ? trustHTML(desc) : undefined;
  }

  <template>
    <@form.Alert @type="info">
      {{this.description}}
    </@form.Alert>
  </template>
}
```

- [ ] **Step 2: Write `code-control.gjs`**

Field-wrapped renderer. Extracts `field.gjs:300-311`. No ExpressionWrapper (code fields don't support expression mode).

```js
import Component from "@glimmer/component";

export default class CodeControl extends Component {
  get height() {
    return this.args.schema?.ui?.height;
  }

  get lang() {
    return this.args.schema?.ui?.lang || "text";
  }

  <template>
    <@field.Control @height={{this.height}} @lang={{this.lang}} />
  </template>
}
```

- [ ] **Step 3: Write `icon-control.gjs`**

Field-wrapped renderer. Renders `<field.Control />` wrapped in ExpressionWrapper.

```js
import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <@field.Control />
  </ExpressionWrapper>
</template>
```

- [ ] **Step 4: Write `default-input-control.gjs`**

Field-wrapped renderer. Fallback for text/number/password inputs.

```js
import ExpressionWrapper from "./expression-wrapper";

<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <@field.Control placeholder={{@placeholder}} />
  </ExpressionWrapper>
</template>
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/notice-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/code-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/icon-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/default-input-control.gjs
git commit -m "feat(workflows): add notice, code, icon, and default-input renderer components"
```

---

### Task 3: Create SelectControl

Extracts option normalization and select rendering from `field.gjs:149-157` and `field.gjs:451-456`.

**Files:**
- Create: `components/workflows/configurators/select-control.gjs`

- [ ] **Step 1: Write `select-control.gjs`**

```js
import Component from "@glimmer/component";
import {
  normalizeOptions,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export default class SelectControl extends Component {
  get options() {
    return normalizeOptions(this.args.schema.options).map((option) => ({
      ...option,
      label: propertyOptionLabel(
        this.args.nodeDefinition,
        this.args.fieldName,
        option
      ),
    }));
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <@field.Control @includeNone={{false}} as |c|>
        {{#each this.options as |choice|}}
          <c.Option @value={{choice.value}}>{{choice.label}}</c.Option>
        {{/each}}
      </@field.Control>
    </ExpressionWrapper>
  </template>
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/select-control.gjs
git commit -m "feat(workflows): add select renderer component"
```

---

### Task 4: Create BooleanControl with test

The most complex renderer. Standalone because it switches between `@form.Field @type="toggle"` (plain) and `@type="custom"` (expression mode). Owns its own expression-mode tracked state.

**Files:**
- Create: `components/workflows/configurators/boolean-control.gjs`
- Create: `test/javascripts/integration/components/workflows/boolean-control-test.gjs`

- [ ] **Step 1: Write failing test**

```js
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BooleanControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/boolean-control";

module(
  "Integration | Component | workflows boolean control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders toggle in plain mode", async function (assert) {
      this.setProperties({
        configuration: { enabled: false },
        formApi: null,
        schema: { type: "boolean", ui: { expression: true } },
        registerApi: (api) => this.set("formApi", api),
      });

      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onRegisterApi={{this.registerApi}}
            as |form transientData|
          >
            <BooleanControl
              @form={{form}}
              @formApi={{this.formApi}}
              @configuration={{transientData}}
              @fieldName="enabled"
              @label="Enabled"
              @schema={{this.schema}}
            />
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-toggle").exists();
      assert.dom(".workflows-property-engine__mode-control").exists();
    });

    test("switches to expression mode", async function (assert) {
      this.setProperties({
        configuration: { enabled: false },
        formApi: null,
        schema: { type: "boolean", ui: { expression: true } },
        registerApi: (api) => this.set("formApi", api),
      });

      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onRegisterApi={{this.registerApi}}
            as |form transientData|
          >
            <BooleanControl
              @form={{form}}
              @formApi={{this.formApi}}
              @configuration={{transientData}}
              @fieldName="enabled"
              @label="Enabled"
              @schema={{this.schema}}
            />
          </Form>
        </template>
      );

      await click(
        '.workflows-property-engine__mode-control input[value="dynamic"]'
      );

      assert.dom(".form-kit__control-toggle").doesNotExist();
      assert.dom(".workflows-variable-input").exists();
    });

    test("renders in expression mode when value starts with =", async function (assert) {
      this.setProperties({
        configuration: { enabled: "=true" },
        schema: { type: "boolean", ui: { expression: true } },
      });

      await render(
        <template>
          <Form @data={{this.configuration}} as |form transientData|>
            <BooleanControl
              @form={{form}}
              @configuration={{transientData}}
              @fieldName="enabled"
              @label="Enabled"
              @schema={{this.schema}}
            />
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-toggle").doesNotExist();
      assert.dom(".workflows-variable-input").exists();
    });

    test("renders plain toggle without mode control when expressions disabled", async function (assert) {
      this.setProperties({
        configuration: { enabled: false },
        schema: { type: "boolean", ui: { expression: false } },
      });

      await render(
        <template>
          <Form @data={{this.configuration}} as |form transientData|>
            <BooleanControl
              @form={{form}}
              @configuration={{transientData}}
              @fieldName="enabled"
              @label="Enabled"
              @schema={{this.schema}}
            />
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-toggle").exists();
      assert.dom(".workflows-property-engine__mode-control").doesNotExist();
    });
  }
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/qunit plugins/discourse-workflows/test/javascripts/integration/components/workflows/boolean-control-test.gjs`
Expected: FAIL — `BooleanControl` module not found.

- [ ] **Step 3: Write `boolean-control.gjs`**

Extracts `field.gjs:256-299` plus its expression-mode management.

```js
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";
import {
  fieldFormat,
  fieldShowDescription,
  fieldSupportsExpression,
  isExpression,
  propertyDescription,
  propertyLabel,
  propertyPlaceholder,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

const MODE_ITEMS = [
  {
    value: "plain",
    icon: "paragraph",
    label: i18n("discourse_workflows.parameter_field.plain"),
  },
  {
    value: "dynamic",
    icon: "code",
    label: i18n("discourse_workflows.parameter_field.dynamic"),
  },
];

export default class BooleanControl extends Component {
  @tracked expressionMode = this.#initialExpressionMode();

  #initialExpressionMode() {
    if (!fieldSupportsExpression(this.args.schema)) {
      return false;
    }
    return isExpression(this.args.configuration?.[this.args.fieldName]);
  }

  get supportsExpression() {
    return fieldSupportsExpression(this.args.schema);
  }

  get format() {
    return fieldFormat(this.args.schema);
  }

  get label() {
    return this.args.label || propertyLabel(this.args.nodeDefinition, this.args.fieldName);
  }

  get placeholder() {
    return propertyPlaceholder(this.args.nodeDefinition, this.args.fieldName);
  }

  get tooltip() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    return propertyDescription(this.args.nodeDefinition, this.args.fieldName);
  }

  get validation() {
    return this.args.schema?.required ? "required" : undefined;
  }

  @action
  onModeChange(field, value) {
    const wantsDynamic = value === "dynamic";
    if (wantsDynamic === this.expressionMode) {
      return;
    }

    this.expressionMode = wantsDynamic;
    const currentValue = field.value || "";

    if (wantsDynamic) {
      field.set(
        currentValue.startsWith("=") ? currentValue : `=${currentValue}`
      );
    } else {
      field.set(
        currentValue.startsWith("=") ? currentValue.slice(1) : currentValue
      );
    }
  }

  <template>
    {{#if this.expressionMode}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.label}}
        @showTitle={{true}}
        @type="custom"
        @format={{this.format}}
        @onSet={{@onSet}}
        as |field|
      >
        <field.Control>
          <ExpressionWrapper
            @field={{field}}
            @supportsExpression={{this.supportsExpression}}
            @placeholder={{this.placeholder}}
          />
        </field.Control>
      </@form.Field>
    {{else}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.label}}
        @tooltip={{this.tooltip}}
        @type="toggle"
        @format={{this.format}}
        @validation={{this.validation}}
        as |field|
      >
        <field.Control />
        {{#if this.supportsExpression}}
          <DSegmentedControl
            @items={{MODE_ITEMS}}
            @value="plain"
            @onSelect={{fn this.onModeChange field}}
            @size="small"
            class="workflows-property-engine__mode-control --toggle"
          />
        {{/if}}
      </@form.Field>
    {{/if}}
  </template>
}
```

Note: BooleanControl keeps its own `@tracked expressionMode` and `onModeChange` because it needs to know the mode BEFORE `<@form.Field>` yields `field` (to choose between `type="toggle"` and `type="custom"`). ExpressionWrapper handles the expression input rendering when in expression mode.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/qunit plugins/discourse-workflows/test/javascripts/integration/components/workflows/boolean-control-test.gjs`
Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/boolean-control.gjs plugins/discourse-workflows/test/javascripts/integration/components/workflows/boolean-control-test.gjs
git commit -m "feat(workflows): add boolean renderer component with toggle/expression switching"
```

---

### Task 5: Create control registry module

The central mapping from control names to `{ kind, type, renderer }` entries.

**Files:**
- Create: `lib/workflows/control-registry.js`

- [ ] **Step 1: Write `control-registry.js`**

```js
import BooleanControl from "../../components/workflows/configurators/boolean-control";
import CategoryControl from "../../components/workflows/configurators/category-control";
import CodeControl from "../../components/workflows/configurators/code-control";
import ComboBox from "../../components/workflows/configurators/combo-box";
import ConditionBuilder from "../../components/workflows/configurators/condition-builder";
import Credential from "../../components/workflows/configurators/credential";
import DataTableColumnSelect from "../../components/workflows/configurators/data-table-column-select";
import DataTableColumns from "../../components/workflows/configurators/data-table-columns";
import DataTableConditionBuilder from "../../components/workflows/configurators/data-table-condition-builder";
import DefaultInputControl from "../../components/workflows/configurators/default-input-control";
import FilterQuery from "../../components/workflows/configurators/filter-query";
import IconControl from "../../components/workflows/configurators/icon-control";
import MultiComboBox from "../../components/workflows/configurators/multi-combo-box";
import NoticeControl from "../../components/workflows/configurators/notice-control";
import SelectControl from "../../components/workflows/configurators/select-control";
import TagsControl from "../../components/workflows/configurators/tags-control";
import UrlPreview from "../../components/workflows/configurators/url-preview";
import UserControl from "../../components/workflows/configurators/user-control";
import UserOrGroupControl from "../../components/workflows/configurators/user-or-group-control";

const CONTROL_REGISTRY = {
  notice: { kind: "standalone", renderer: NoticeControl },
  boolean: { kind: "standalone", renderer: BooleanControl },
  condition_builder: { kind: "standalone", renderer: ConditionBuilder },
  data_table_condition_builder: {
    kind: "standalone",
    renderer: DataTableConditionBuilder,
  },
  data_table_columns: { kind: "standalone", renderer: DataTableColumns },

  code: { kind: "field", type: "code", renderer: CodeControl },
  combo_box: { kind: "field", type: "custom", renderer: ComboBox },
  credential: { kind: "field", type: "custom", renderer: Credential },
  data_table_column_select: {
    kind: "field",
    type: "custom",
    renderer: DataTableColumnSelect,
  },
  multi_combo_box: { kind: "field", type: "custom", renderer: MultiComboBox },
  filter_query: { kind: "field", type: "custom", renderer: FilterQuery },
  url_preview: { kind: "field", type: "custom", renderer: UrlPreview },
  tags: { kind: "field", type: "custom", renderer: TagsControl },
  category: { kind: "field", type: "custom", renderer: CategoryControl },
  user: { kind: "field", type: "custom", renderer: UserControl },
  user_or_group: { kind: "field", type: "custom", renderer: UserOrGroupControl },
  select: { kind: "field", type: "select", renderer: SelectControl },
  icon: { kind: "field", type: "icon", renderer: IconControl },

  default: {
    kind: "field",
    type: ({ inputType }) => `input-${inputType}`,
    renderer: DefaultInputControl,
  },
};

export default CONTROL_REGISTRY;
```

- [ ] **Step 2: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/lib/workflows/control-registry.js
git commit -m "feat(workflows): add control registry module"
```

---

### Task 6: Refactor ExpressionWrapper to own expression-mode state

ExpressionWrapper derives mode from `@field.value` and owns the mode toggle action. This eliminates the `@expressionMode`, `@modeItems`, and `@onModeChange` props.

**Important:** This change is made in preparation for Task 7. ExpressionWrapper needs backward compatibility during the transition — it checks for an explicit `@expressionMode` prop first, falling back to derived mode. Task 7 removes all callers that pass `@expressionMode`, and Task 8 removes the backward compat.

**Files:**
- Modify: `components/workflows/configurators/expression-wrapper.gjs`

- [ ] **Step 1: Read the current file**

Read `components/workflows/configurators/expression-wrapper.gjs` to confirm current state.

- [ ] **Step 2: Update ExpressionWrapper**

Replace the entire file:

```js
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import { isExpression } from "../../../lib/workflows/property-engine";
import ExpressionInput from "./expression-input";

const MODE_ITEMS = [
  {
    value: "plain",
    icon: "paragraph",
    label: i18n("discourse_workflows.parameter_field.plain"),
  },
  {
    value: "dynamic",
    icon: "code",
    label: i18n("discourse_workflows.parameter_field.dynamic"),
  },
];

export default class ExpressionWrapper extends Component {
  @service workflowsNodeTypes;

  @tracked isDragOver = false;

  get expressionMode() {
    return isExpression(this.args.field?.value);
  }

  @action
  toggleMode(value) {
    const wantsDynamic = value === "dynamic";
    if (wantsDynamic === this.expressionMode) {
      return;
    }

    const currentValue = this.args.field.value || "";

    if (wantsDynamic) {
      this.args.field.set(
        currentValue.startsWith("=") ? currentValue : `=${currentValue}`
      );
    } else {
      this.args.field.set(
        currentValue.startsWith("=") ? currentValue.slice(1) : currentValue
      );
    }
  }

  @action
  handleDragOver(event) {
    if (!this.args.supportsExpression || this.expressionMode) {
      return;
    }
    if (event.dataTransfer.types.includes("application/x-workflow-variable")) {
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
      this.isDragOver = true;
    }
  }

  @action
  handleDragLeave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.isDragOver = false;
    }
  }

  @action
  handleDrop(event) {
    if (!this.args.supportsExpression || this.expressionMode) {
      return;
    }

    const data = event.dataTransfer.getData("application/x-workflow-variable");
    if (!data) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = false;

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    const prefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
    const variableId = variable.id.startsWith("$")
      ? variable.id
      : `${prefix}.${variable.id}`;

    this.args.field.set(`={{ ${variableId} }}`);
  }

  <template>
    <div
      class={{concatClass
        "workflows-property-engine__control-wrapper"
        (if this.isDragOver "is-drag-over")
      }}
      data-supports-expression={{if @supportsExpression "true"}}
      {{on "dragover" this.handleDragOver}}
      {{on "dragleave" this.handleDragLeave}}
      {{on "drop" this.handleDrop}}
    >
      {{#if this.expressionMode}}
        <ExpressionInput
          @field={{@field}}
          @placeholder={{@placeholder}}
          @autofocus={{true}}
        />
      {{else}}
        {{yield}}
      {{/if}}

      {{#if @supportsExpression}}
        <DSegmentedControl
          @items={{MODE_ITEMS}}
          @value={{if this.expressionMode "dynamic" "plain"}}
          @onSelect={{this.toggleMode}}
          @size="small"
          class="workflows-property-engine__mode-control"
        />
      {{/if}}
    </div>
  </template>
}
```

Key changes from the original:
- `expressionMode` is now a derived getter using `isExpression(this.args.field?.value)` instead of `this.args.expressionMode`
- `toggleMode` action replaces `@onModeChange` — ExpressionWrapper manipulates `@field.value` directly
- `MODE_ITEMS` moved here from `field.gjs`
- `handleDrop` no longer calls `this.args.onModeChange` — setting the value with `=` prefix is sufficient
- Removed props: `@expressionMode`, `@modeItems`, `@onModeChange`
- New required prop: `@field` (was already passed in all usages)

- [ ] **Step 3: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/expression-wrapper.gjs
git commit -m "refactor(workflows): ExpressionWrapper derives expression mode from field value"
```

---

### Task 7: Update existing configurators to include ExpressionWrapper

Each existing custom configurator component wraps its content in `<ExpressionWrapper>`. DataTableColumns absorbs its visibility guard and section wrapper. DataTableConditionBuilder switches from `@dataTableId` to `@configuration`.

**Important:** These changes are made in preparation for Task 8 (refactoring Field). The existing configurators don't currently include ExpressionWrapper — Field wraps them. After Task 8, Field no longer wraps them, so they must include it themselves.

**Do not run tests between Task 7 and Task 8** — the double-wrapping during the transition would cause rendering issues. Complete both tasks, then test.

**Files:**
- Modify: `components/workflows/configurators/combo-box.gjs`
- Modify: `components/workflows/configurators/credential.gjs`
- Modify: `components/workflows/configurators/data-table-column-select.gjs`
- Modify: `components/workflows/configurators/multi-combo-box.gjs`
- Modify: `components/workflows/configurators/filter-query.gjs`
- Modify: `components/workflows/configurators/url-preview.gjs`
- Modify: `components/workflows/configurators/data-table-columns.gjs`
- Modify: `components/workflows/configurators/data-table-condition-builder.gjs`

- [ ] **Step 1: Update `combo-box.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 109-118) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <ComboBox
      @content={{this.options}}
      @nameProperty="name"
      @value={{@field.value}}
      @valueProperty="id"
      @onChange={{this.handleChange}}
      @options={{hash filterable=this.filterable none=this.none}}
    />
  </ExpressionWrapper>
</template>
```

- [ ] **Step 2: Update `credential.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 64-83) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <div class="workflows-property-engine-credential">
      <ComboBox
        @content={{this.options}}
        @value={{@field.value}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash none="discourse_workflows.credentials.select_type"}}
      />
      {{#unless @field.value}}
        <DButton
          @action={{this.setupCredential}}
          @label="discourse_workflows.credentials.set_up_credential"
          @icon="plus"
          class="btn-default"
        />
      {{/unless}}
    </div>
  </ExpressionWrapper>
</template>
```

- [ ] **Step 3: Update `data-table-column-select.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 33-45) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    {{#if this.options.length}}
      <ComboBox
        class="workflows-data-table-column-select"
        @content={{this.options}}
        @nameProperty="name"
        @value={{@field.value}}
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash none=this.none}}
      />
    {{/if}}
  </ExpressionWrapper>
</template>
```

- [ ] **Step 4: Update `multi-combo-box.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 29-35) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    <MultiSelect
      @content={{this.options}}
      @value={{this.value}}
      @onChange={{@field.set}}
    />
  </ExpressionWrapper>
</template>
```

- [ ] **Step 5: Update `filter-query.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 29-37) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    {{#if this.tips}}
      <FilterNavigationMenu
        @initialInputValue={{@field.value}}
        @onChange={{this.handleChange}}
        @tips={{this.tips}}
      />
    {{/if}}
  </ExpressionWrapper>
</template>
```

- [ ] **Step 6: Update `url-preview.gjs`**

Add import for `ExpressionWrapper` and wrap the template content:

Add import:
```js
import ExpressionWrapper from "./expression-wrapper";
```

Replace the template (lines 56-72) with:
```hbs
<template>
  <ExpressionWrapper
    @field={{@field}}
    @supportsExpression={{@supportsExpression}}
    @placeholder={{@placeholder}}
  >
    {{#if this.hasUrl}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class={{concatClass
          "workflows-url-preview"
          (if this.copied "is-copied")
        }}
        title={{i18n "discourse_workflows.webhook.click_to_copy"}}
        {{on "click" this.copy}}
      >
        <code>{{this.previewUrl}}</code>
        {{icon (if this.copied "check" "copy")}}
      </div>
    {{else if this.hint}}
      <p class="workflows-url-preview__hint">{{this.hint}}</p>
    {{/if}}
  </ExpressionWrapper>
</template>
```

- [ ] **Step 7: Update `data-table-columns.gjs`**

Add `<@form.Section @title={{@label}}>` wrapper around content. The `{{#if @configuration.data_table_id}}` guard from `field.gjs:333` is already handled by the existing `{{#if this.columns.length}}` guard (when there's no `data_table_id`, `columns` is empty).

Replace the template (lines 29-44) with:
```hbs
<template>
  {{#if this.columns.length}}
    <@form.Section @title={{@label}}>
      <@form.Object @name={{@fieldName}} as |object|>
        {{#each this.columns key="name" as |column|}}
          <Field
            @form={{object}}
            @formApi={{@formApi}}
            @fieldName={{column.name}}
            @formApiPath={{concat @fieldName "." column.name}}
            @configuration={{this.columnsConfiguration}}
            @label={{column.name}}
            @schema={{schemaForColumn column}}
          />
        {{/each}}
      </@form.Object>
    </@form.Section>
  {{/if}}
</template>
```

- [ ] **Step 8: Update `data-table-condition-builder.gjs`**

Change from `@dataTableId` to extracting the value from `@configuration`:

Replace the `dataTable` getter (line 17-19) with:
```js
get dataTable() {
  const id = parseInt(this.args.configuration?.data_table_id, 10);
  return this.args.metadata?.data_tables?.find((dt) => dt.id === id) || null;
}
```

No template changes needed.

- [ ] **Step 9: Commit**

Do NOT run tests yet — Field still wraps these in ExpressionWrapper. Complete Task 8 first.

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/combo-box.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/credential.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-column-select.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/multi-combo-box.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/filter-query.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/url-preview.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-columns.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-condition-builder.gjs
git commit -m "refactor(workflows): configurators include ExpressionWrapper internally"
```

---

### Task 8: Refactor Field to use the registry

Replace Field's 15-branch template with registry-based dispatch. Remove expression-mode state, control-specific actions, and parallel data structures.

**Files:**
- Modify: `components/workflows/configurators/field.gjs`

- [ ] **Step 1: Read the current file**

Read `field.gjs` to confirm current state matches expectations.

- [ ] **Step 2: Rewrite `field.gjs`**

Replace the entire file:

```js
import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";
import {
  fieldControl,
  fieldFormat,
  fieldInputType,
  fieldShowDescription,
  fieldShowLabel,
  fieldSupportsExpression,
  findNodeType,
  isExpression,
  propertyDescription,
  propertyLabel,
  propertyPlaceholder,
} from "../../../lib/workflows/property-engine";
import CONTROL_REGISTRY from "../../../lib/workflows/control-registry";

const CRON_FIELD_PATTERN =
  /^(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+)(,(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+))*$/;

function isValidCron(value) {
  if (!value || typeof value !== "string") {
    return false;
  }
  const fields = value.trim().split(/\s+/);
  return fields.length === 5 && fields.every((f) => CRON_FIELD_PATTERN.test(f));
}

const FIELD_VALIDATORS = {
  cron: (name, value, { addError }) => {
    if (value && !isExpression(value) && !isValidCron(value)) {
      addError(name, {
        title: i18n("discourse_workflows.schedule.cron"),
        message: i18n("discourse_workflows.schedule.cron_invalid"),
      });
    }
  },
};

export default class Field extends Component {
  get control() {
    return fieldControl(this.args.schema);
  }

  get entry() {
    return CONTROL_REGISTRY[this.control] || CONTROL_REGISTRY.default;
  }

  get renderer() {
    return this.entry.renderer;
  }

  get resolvedFieldType() {
    const { type } = this.entry;
    if (typeof type === "function") {
      return type({ inputType: this.inputType });
    }
    return type;
  }

  get isCustomType() {
    return this.resolvedFieldType === "custom";
  }

  get inputType() {
    return fieldInputType(this.args.schema);
  }

  get label() {
    return (
      this.args.label || propertyLabel(this.nodeDefinition, this.args.fieldName)
    );
  }

  get metadata() {
    return this.args.metadata || this.nodeDefinition?.metadata || {};
  }

  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.nodeType)
    );
  }

  get nodeType() {
    return this.args.nodeType || this.args.node?.type;
  }

  get placeholder() {
    return propertyPlaceholder(this.nodeDefinition, this.args.fieldName);
  }

  get showLabel() {
    return fieldShowLabel(this.args.schema);
  }

  get format() {
    return fieldFormat(this.args.schema);
  }

  get supportsExpression() {
    return fieldSupportsExpression(this.args.schema);
  }

  get validation() {
    return this.args.schema?.required ? "required" : undefined;
  }

  get customValidation() {
    return FIELD_VALIDATORS[this.args.schema?.validate];
  }

  get fieldDescription() {
    if (!fieldShowDescription(this.args.schema)) {
      return undefined;
    }
    const description = propertyDescription(
      this.nodeDefinition,
      this.args.fieldName
    );
    return description ? trustHTML(description) : undefined;
  }

  get fieldTitle() {
    return this.label || this.args.fieldName || "-";
  }

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
        @onSet={{@onSet}}
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
        {{#if this.isCustomType}}
          <field.Control>
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
          </field.Control>
        {{else}}
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
        {{/if}}
      </@form.Field>
    {{/if}}
  </template>
}
```

What was removed from Field:
- `@tracked expressionMode` and `#initialExpressionMode()`
- `onModeChange`, `handleUserChange`, `handleTagChange` actions
- `tagValue` helper
- `MODE_ITEMS` constant (moved to ExpressionWrapper and BooleanControl)
- `CUSTOM_CONTROLS` set
- `CONTROL_TO_FIELD_TYPE` map
- `fieldType` getter (replaced by `resolvedFieldType`)
- `codeHeight`, `codeLang` getters (moved to CodeControl)
- `fieldTooltip` getter (moved to BooleanControl)
- `options` getter (moved to SelectControl)
- All 17 component imports (replaced by single registry import)
- The 15-branch conditional template

- [ ] **Step 3: Run regression tests**

Run: `bin/qunit plugins/discourse-workflows/test/javascripts/integration/components/workflows/property-engine-test.gjs`
Expected: All 7 tests PASS.

Also run: `bin/qunit plugins/discourse-workflows/test/javascripts/integration/components/workflows/boolean-control-test.gjs`
Expected: All 4 tests PASS.

- [ ] **Step 4: Lint all changed files**

```bash
bin/lint --fix plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/field.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/expression-wrapper.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/combo-box.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/credential.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-column-select.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/multi-combo-box.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/filter-query.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/url-preview.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-columns.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/data-table-condition-builder.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/lib/workflows/control-registry.js
```

Fix any lint errors.

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/field.gjs
git commit -m "refactor(workflows): Field uses registry-based dispatch

Replace 15-branch conditional template with two-branch dispatch
(standalone vs field-wrapped) using CONTROL_REGISTRY. Field remains
the public facade; renderers own domain behavior."
```

---

### Task 9: Lint and run full test suite

Final validation that all changes work together.

**Files:** None (verification only)

- [ ] **Step 1: Lint all new files**

```bash
bin/lint plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/tags-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/category-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/user-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/user-or-group-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/notice-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/code-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/icon-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/default-input-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/select-control.gjs plugins/discourse-workflows/admin/assets/javascripts/admin/components/workflows/configurators/boolean-control.gjs
```

- [ ] **Step 2: Run all workflow JS tests**

```bash
bin/qunit plugins/discourse-workflows/test/javascripts/
```

Expected: All tests pass.

- [ ] **Step 3: Fix any failures**

If tests fail, diagnose and fix. Common issues:
- Missing arg in a renderer (check the arg surface matches what Field passes)
- ExpressionWrapper not finding `@field.value` (ensure `@field` is passed)
- `@field.Control` not rendering (verify contextual component passing works)

- [ ] **Step 4: Final commit if fixes were needed**

```bash
git add -u
git commit -m "fix(workflows): address test failures from field configurator refactoring"
```
