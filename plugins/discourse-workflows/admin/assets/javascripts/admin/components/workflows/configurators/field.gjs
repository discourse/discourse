import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CONTROL_REGISTRY from "../../../lib/workflows/control-registry";
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
