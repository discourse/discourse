import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DSegmentedControl from "discourse/components/d-segmented-control";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { eq } from "discourse/truth-helpers";
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
  normalizeOptions,
  propertyDescription,
  propertyLabel,
  propertyOptionLabel,
  propertyPlaceholder,
} from "../../../lib/workflows/property-engine";
import ComboBox from "./combo-box";
import ConditionBuilder from "./condition-builder";
import Credential from "./credential";
import DataTableColumnSelect from "./data-table-column-select";
import DataTableColumns from "./data-table-columns";
import DataTableConditionBuilder from "./data-table-condition-builder";
import ExpressionWrapper from "./expression-wrapper";
import FilterQuery from "./filter-query";
import MultiComboBox from "./multi-combo-box";
import UrlPreview from "./url-preview";

const CRON_FIELD_PATTERN =
  /^(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+)(,(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+))*$/;

function isValidCron(value) {
  if (!value || typeof value !== "string") {
    return false;
  }
  const fields = value.trim().split(/\s+/);
  return fields.length === 5 && fields.every((f) => CRON_FIELD_PATTERN.test(f));
}

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

const CUSTOM_CONTROLS = new Set([
  "combo_box",
  "credential",
  "data_table_column_select",
  "filter_query",
  "multi_combo_box",
  "url_preview",
  "category",
  "user",
  "user_or_group",
  "tags",
]);

const CONTROL_TO_FIELD_TYPE = {
  icon: "icon",
  select: "select",
  textarea: "textarea",
};

function tagValue(value) {
  if (Array.isArray(value)) {
    return value;
  }
  if (typeof value === "string" && value.length > 0) {
    return value.split(",").map((t) => t.trim());
  }
  return [];
}

const FIELD_VALIDATORS = {
  cron: (name, value, { addError }) => {
    if (value && !isValidCron(value)) {
      addError(name, {
        title: i18n("discourse_workflows.schedule.cron"),
        message: i18n("discourse_workflows.schedule.cron_invalid"),
      });
    }
  },
};

export default class Field extends Component {
  @tracked expressionMode = this.#initialExpressionMode();

  #initialExpressionMode() {
    if (!fieldSupportsExpression(this.args.schema)) {
      return false;
    }
    return isExpression(this.args.configuration?.[this.args.fieldName]);
  }

  get control() {
    return fieldControl(this.args.schema);
  }

  get fieldType() {
    if (CUSTOM_CONTROLS.has(this.control)) {
      return "custom";
    }
    return CONTROL_TO_FIELD_TYPE[this.control] || `input-${this.inputType}`;
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

  get options() {
    return normalizeOptions(this.args.schema.options).map((option) => ({
      ...option,
      label: propertyOptionLabel(
        this.nodeDefinition,
        this.args.fieldName,
        option
      ),
    }));
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
    if (this.expressionMode) {
      return undefined;
    }
    return FIELD_VALIDATORS[this.args.schema?.validate];
  }

  get codeHeight() {
    return this.args.schema?.ui?.height;
  }

  get codeLang() {
    return this.args.schema?.ui?.lang || "text";
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

  @action
  handleUserChange(field, usernames) {
    field.set(usernames[0] || "");
  }

  @action
  handleTagChange(field, tags) {
    const names = (tags || []).map((t) =>
      typeof t === "string" ? t : t.name || t.id || t
    );
    field.set(names);
  }

  <template>
    {{#if (eq this.control "notice")}}
      <@form.Alert @type="info">
        {{this.fieldDescription}}
      </@form.Alert>
    {{else if (eq this.control "boolean")}}
      {{#if this.expressionMode}}
        <@form.Field
          @name={{@fieldName}}
          @title={{this.fieldTitle}}
          @showTitle={{this.showLabel}}
          @type="custom"
          @format={{this.format}}
          @onSet={{@onSet}}
          as |field|
        >
          <field.Control>
            <ExpressionWrapper
              @expressionMode={{true}}
              @field={{field}}
              @placeholder={{this.placeholder}}
              @supportsExpression={{this.supportsExpression}}
              @modeItems={{MODE_ITEMS}}
              @onModeChange={{fn this.onModeChange field}}
            />
          </field.Control>
        </@form.Field>
      {{else}}
        <@form.Field
          @name={{@fieldName}}
          @title={{this.label}}
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
    {{else if (eq this.control "code")}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @type="code"
        @format={{this.format}}
        @validation={{this.validation}}
        as |field|
      >
        <field.Control @height={{this.codeHeight}} @lang={{this.codeLang}} />
      </@form.Field>
    {{else if (eq this.control "condition_builder")}}
      <ConditionBuilder
        @form={{@form}}
        @formApi={{@formApi}}
        @fieldName={{@fieldName}}
        @label={{this.fieldTitle}}
        @node={{@node}}
        @nodes={{@nodes}}
        @connections={{@connections}}
        @nodeTypes={{@nodeTypes}}
      />
    {{else if (eq this.control "data_table_condition_builder")}}
      <DataTableConditionBuilder
        @form={{@form}}
        @formApi={{@formApi}}
        @fieldName={{@fieldName}}
        @label={{this.fieldTitle}}
        @dataTableId={{@configuration.data_table_id}}
        @metadata={{this.metadata}}
      />
    {{else if (eq this.control "data_table_columns")}}
      <@form.Section @title={{this.fieldTitle}}>
        <DataTableColumns
          @form={{@form}}
          @formApi={{@formApi}}
          @fieldName={{@fieldName}}
          @configuration={{@configuration}}
          @metadata={{this.metadata}}
        />
      </@form.Section>
    {{else if (eq this.fieldType "custom")}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @description={{this.fieldDescription}}
        @type="custom"
        @format={{this.format}}
        @validation={{this.validation}}
        @validate={{this.customValidation}}
        @onSet={{@onSet}}
        as |field|
      >
        <field.Control>
          <ExpressionWrapper
            @expressionMode={{this.expressionMode}}
            @field={{field}}
            @placeholder={{this.placeholder}}
            @supportsExpression={{this.supportsExpression}}
            @modeItems={{MODE_ITEMS}}
            @onModeChange={{fn this.onModeChange field}}
          >
            {{#if (eq this.control "combo_box")}}
              <ComboBox
                @field={{field}}
                @fieldName={{@fieldName}}
                @formApi={{@formApi}}
                @metadata={{this.metadata}}
                @nodeDefinition={{this.nodeDefinition}}
                @schema={{@schema}}
              />
            {{else if (eq this.control "credential")}}
              <Credential
                @field={{field}}
                @fieldName={{@fieldName}}
                @formApi={{@formApi}}
                @nodeDefinition={{this.nodeDefinition}}
                @schema={{@schema}}
              />
            {{else if (eq this.control "data_table_column_select")}}
              <DataTableColumnSelect
                @configuration={{@configuration}}
                @field={{field}}
                @fieldName={{@fieldName}}
                @metadata={{this.metadata}}
                @nodeDefinition={{this.nodeDefinition}}
                @schema={{@schema}}
              />
            {{else if (eq this.control "multi_combo_box")}}
              <MultiComboBox
                @field={{field}}
                @fieldName={{@fieldName}}
                @nodeDefinition={{this.nodeDefinition}}
                @schema={{@schema}}
              />
            {{else if (eq this.control "filter_query")}}
              <FilterQuery @field={{field}} @schema={{@schema}} />
            {{else if (eq this.control "url_preview")}}
              <UrlPreview @configuration={{@configuration}} @field={{field}} />
            {{else if (eq this.control "tags")}}
              <MiniTagChooser
                @value={{tagValue field.value}}
                @onChange={{fn this.handleTagChange field}}
              />
            {{else if (eq this.control "category")}}
              <CategoryChooser @value={{field.value}} @onChange={{field.set}} />
            {{else if (eq this.control "user")}}
              <UserChooser
                @value={{if field.value field.value null}}
                @onChange={{fn this.handleUserChange field}}
                @options={{hash maximum=1 excludeCurrentUser=false}}
              />
            {{else if (eq this.control "user_or_group")}}
              <EmailGroupUserChooser
                @value={{if field.value field.value null}}
                @onChange={{fn this.handleUserChange field}}
                @options={{hash
                  maximum=1
                  includeGroups=true
                  excludeCurrentUser=false
                }}
              />
            {{/if}}
          </ExpressionWrapper>
        </field.Control>
      </@form.Field>
    {{else}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @description={{this.fieldDescription}}
        @type={{this.fieldType}}
        @format={{this.format}}
        @validation={{this.validation}}
        @validate={{this.customValidation}}
        @onSet={{@onSet}}
        as |field|
      >
        <ExpressionWrapper
          @expressionMode={{this.expressionMode}}
          @field={{field}}
          @placeholder={{this.placeholder}}
          @supportsExpression={{this.supportsExpression}}
          @modeItems={{MODE_ITEMS}}
          @onModeChange={{fn this.onModeChange field}}
        >
          {{#if (eq this.control "select")}}
            <field.Control @includeNone={{false}} as |c|>
              {{#each this.options as |choice|}}
                <c.Option @value={{choice.value}}>{{choice.label}}</c.Option>
              {{/each}}
            </field.Control>
          {{else if (eq this.control "icon")}}
            <field.Control />
          {{else}}
            <field.Control placeholder={{this.placeholder}} />
          {{/if}}
        </ExpressionWrapper>
      </@form.Field>
    {{/if}}
  </template>
}
