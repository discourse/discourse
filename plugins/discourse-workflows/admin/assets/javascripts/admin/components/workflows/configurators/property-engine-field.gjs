import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import FKControlInput from "discourse/form-kit/components/fk/control/input";
import FKControlSelect from "discourse/form-kit/components/fk/control/select";
import FKControlTextarea from "discourse/form-kit/components/fk/control/textarea";
import { applyValueTransformer } from "discourse/lib/transformer";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  fieldControl,
  fieldInputType,
  fieldRows,
  fieldShowDescription,
  fieldShowLabel,
  fieldSupportsExpression,
  findNodeType,
  normalizeOptions,
  propertyDescription,
  propertyLabel,
  propertyOptionLabel,
  propertyPlaceholder,
} from "../../../lib/workflows/property-engine";
import ExpressionInput from "./expression-input";
import PropertyEngineComboBox from "./property-engine-combo-box";
import PropertyEngineConditionBuilder from "./property-engine-condition-builder";
import PropertyEngineDataTableFields from "./property-engine-data-table-fields";
import PropertyEngineFilterQuery from "./property-engine-filter-query";
import PropertyEngineUrlPreview from "./property-engine-url-preview";

const BUILT_IN_FIELD_CONTROLS = {
  combo_box: PropertyEngineComboBox,
  data_table_fields: PropertyEngineDataTableFields,
  filter_query: PropertyEngineFilterQuery,
  url_preview: PropertyEngineUrlPreview,
};

function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
}

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
    if (value && !isValidCron(value)) {
      addError(name, {
        title: i18n("discourse_workflows.schedule.cron"),
        message: i18n("discourse_workflows.schedule.cron_invalid"),
      });
    }
  },
};

export default class PropertyEngineField extends Component {
  @tracked _expressionMode = null;

  get control() {
    return fieldControl(this.args.schema);
  }

  get controlComponent() {
    return applyValueTransformer(
      "workflow-property-engine-controls",
      BUILT_IN_FIELD_CONTROLS
    )[this.control];
  }

  get description() {
    return propertyDescription(this.nodeDefinition, this.args.fieldName);
  }

  get inputType() {
    return fieldInputType(this.args.schema);
  }

  get label() {
    return propertyLabel(this.nodeDefinition, this.args.fieldName);
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

  get rows() {
    return fieldRows(this.args.schema);
  }

  get showDescription() {
    return fieldShowDescription(this.args.schema);
  }

  get showLabel() {
    return fieldShowLabel(this.args.schema);
  }

  get supportsExpression() {
    return fieldSupportsExpression(this.args.schema);
  }

  get apiPath() {
    return this.args.formApiPath || this.args.fieldName;
  }

  get expressionMode() {
    if (this._expressionMode !== null) {
      return this._expressionMode;
    }
    if (!this.supportsExpression) {
      return false;
    }
    return isExpression(this.args.formApi?.get(this.apiPath));
  }

  get validation() {
    return this.args.schema?.required ? "required" : undefined;
  }

  get customValidation() {
    const key = this.args.schema?.validate;
    return key ? FIELD_VALIDATORS[key] : undefined;
  }

  get codeHeight() {
    return this.args.schema?.ui?.height;
  }

  get codeLang() {
    return this.args.schema?.ui?.lang || "text";
  }

  get fieldDescription() {
    if (this.showDescription && this.description) {
      return trustHTML(this.description);
    }
    return undefined;
  }

  get fieldTitle() {
    return this.label || this.args.fieldName || "-";
  }

  @action
  toggleExpressionMode() {
    const currentVal = this.args.formApi?.get(this.apiPath) || "";

    if (this.expressionMode) {
      if (isExpression(currentVal)) {
        this.args.formApi?.set(this.apiPath, currentVal.slice(1));
      }
      this._expressionMode = false;
    } else {
      if (!isExpression(currentVal)) {
        this.args.formApi?.set(this.apiPath, `=${currentVal}`);
      }
      this._expressionMode = true;
    }
  }

  @action
  handleSet(value, { set, name }) {
    if (this.args.onSet) {
      this.args.onSet(value, { set, name });
    } else {
      set(name, value);
    }
  }

  @action
  handlePatch(patch) {
    const api = this.args.formApi;
    if (api) {
      for (const [key, value] of Object.entries(patch || {})) {
        api.set(key, value);
      }
    }
  }

  @action
  handleUserChange(field, usernames) {
    field.set(usernames[0] || "");
  }

  @action
  handleInlineChange(fieldSet, valueOrEvent) {
    const value =
      valueOrEvent?.target && "value" in valueOrEvent.target
        ? valueOrEvent.target.value
        : valueOrEvent;
    fieldSet(value);
  }

  @action
  handleInlineToggle(fieldSet, currentValue) {
    fieldSet(!currentValue);
  }

  <template>
    {{#if @inline}}
      {{#if (eq this.control "select")}}
        <select required={{@schema.required}} {{on "change" @onInlineChange}}>
          {{#each this.options as |choice|}}
            <option
              value={{choice.value}}
              selected={{eq choice.value @inlineValue}}
            >{{choice.label}}</option>
          {{/each}}
        </select>
      {{else if (eq this.control "boolean")}}
        <label class="workflows-property-engine__inline-toggle">
          <input
            type="checkbox"
            checked={{@inlineValue}}
            {{on "change" @onInlineChange}}
          />
          {{this.label}}
        </label>
      {{else}}
        <input
          type={{this.inputType}}
          required={{@schema.required}}
          value={{@inlineValue}}
          placeholder={{this.placeholder}}
          {{on "input" @onInlineChange}}
        />
      {{/if}}
    {{else if (eq this.control "boolean")}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.label}}
        @type="toggle"
        @format="full"
        @validation={{this.validation}}
        as |field|
      >
        <field.Control />
      </@form.Field>
    {{else if (eq this.control "code")}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @type="code"
        @format="full"
        @validation={{this.validation}}
        as |field|
      >
        <field.Control @height={{this.codeHeight}} @lang={{this.codeLang}} />
      </@form.Field>
    {{else if (eq this.control "condition_builder")}}
      <@form.Section @title={{this.fieldTitle}}>
        <PropertyEngineConditionBuilder
          @form={{@form}}
          @formApi={{@formApi}}
          @fieldName={{@fieldName}}
          @node={{@node}}
          @nodes={{@nodes}}
          @connections={{@connections}}
          @nodeTypes={{@nodeTypes}}
        />
      </@form.Section>
    {{else if this.controlComponent}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @description={{this.fieldDescription}}
        @type="custom"
        @format="full"
        @validation={{this.validation}}
        @validate={{this.customValidation}}
        @onSet={{this.handleSet}}
        as |field|
      >
        <field.Control>
          <this.controlComponent
            @configuration={{@configuration}}
            @connections={{@connections}}
            @fieldName={{@fieldName}}
            @metadata={{this.metadata}}
            @node={{@node}}
            @nodeDefinition={{this.nodeDefinition}}
            @nodes={{@nodes}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{@nodeTypes}}
            @onPatch={{this.handlePatch}}
            @schema={{@schema}}
            @value={{field.value}}
          />
        </field.Control>
      </@form.Field>
    {{else}}
      <@form.Field
        @name={{@fieldName}}
        @title={{this.fieldTitle}}
        @showTitle={{this.showLabel}}
        @description={{this.fieldDescription}}
        @type="custom"
        @format="full"
        @validation={{this.validation}}
        @validate={{this.customValidation}}
        @onSet={{this.handleSet}}
        as |field|
      >
        <field.Control>
          <div class="workflows-property-engine__control-wrapper">
            {{#if this.expressionMode}}
              <ExpressionInput
                @field={{field}}
                @placeholder={{this.placeholder}}
                @autofocus={{true}}
              />
            {{else if (eq this.control "category")}}
              <CategoryChooser @value={{field.value}} @onChange={{field.set}} />
            {{else if (eq this.control "user")}}
              <UserChooser
                @value={{if field.value field.value null}}
                @onChange={{fn this.handleUserChange field}}
                @options={{hash maximum=1 excludeCurrentUser=false}}
              />
            {{else if (eq this.control "select")}}
              <FKControlSelect @field={{field}} @includeNone={{false}} as |c|>
                {{#each this.options as |choice|}}
                  <c.Option @value={{choice.value}}>{{choice.label}}</c.Option>
                {{/each}}
              </FKControlSelect>
            {{else if (eq this.control "textarea")}}
              <FKControlTextarea
                @field={{field}}
                placeholder={{this.placeholder}}
              />
            {{else}}
              <FKControlInput
                @field={{field}}
                @type={{this.inputType}}
                placeholder={{this.placeholder}}
              />
            {{/if}}

            {{#if this.supportsExpression}}
              <DButton
                @action={{this.toggleExpressionMode}}
                @icon="code"
                class="btn-transparent btn-small workflows-property-engine__mode-trigger
                  {{if this.expressionMode '--active'}}"
              />
            {{/if}}
          </div>
        </field.Control>
      </@form.Field>
    {{/if}}
  </template>
}
