import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  findNodeType,
  isExpression,
  propertyDescription,
  propertyLabel,
} from "../../../lib/workflows/property-engine";
import Field from "./field";

const ASSIGNMENT_TYPE_LABEL_KEY_PREFIX =
  "discourse_workflows.property_engine.assignment_types";

const DEFAULT_ASSIGNMENT_TYPES = [
  "string",
  "number",
  "boolean",
  "array",
  "object",
];

// Expressions are type-agnostic; plain values only survive a type change when
// they still make sense for the new type.
function valueForType(value, type) {
  if (isExpression(value)) {
    return value;
  }

  if (type === "boolean") {
    return value === true;
  }

  if (typeof value === "boolean") {
    return "";
  }

  return value;
}

function normalizeAssignmentType(type) {
  const option = typeof type === "object" ? { ...type } : { value: type };

  return {
    label_key: `${ASSIGNMENT_TYPE_LABEL_KEY_PREFIX}.${option.value}`,
    ...option,
  };
}

export default class AssignmentCollection extends Component {
  get assignmentsPath() {
    return `${this.args.fieldName}.assignments`;
  }

  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.args.nodeType)
    );
  }

  get label() {
    return propertyLabel(this.nodeDefinition, this.args.fieldName);
  }

  get description() {
    return propertyDescription(this.nodeDefinition, this.args.fieldName);
  }

  get type_options() {
    return this.args.schema.type_options || {};
  }

  get assignmentTypes() {
    return (this.type_options.assignment_types || DEFAULT_ASSIGNMENT_TYPES).map(
      normalizeAssignmentType
    );
  }

  get nameSchema() {
    return {
      type: "string",
      required: true,
      no_data_expression: true,
    };
  }

  get typeSchema() {
    return {
      type: "options",
      required: true,
      default: "string",
      options: this.assignmentTypes,
      no_data_expression: true,
    };
  }

  @action
  emptyAssignment() {
    return {
      id: crypto.randomUUID(),
      name: "",
      value: "",
      type: "string",
    };
  }

  @action
  addAssignment() {
    this.args.form.addItemToCollection(
      this.assignmentsPath,
      this.emptyAssignment()
    );
    this.args.onChange?.();
  }

  @action
  removeAssignment(removeFn, index) {
    removeFn(index);
    this.args.onChange?.();
  }

  @action
  handleTypeChange(index, type, { set, name }) {
    set(name, type);

    if (!this.args.formApi) {
      return;
    }

    const valuePath = `${this.assignmentsPath}.${index}.value`;
    set(valuePath, valueForType(this.args.formApi.get(valuePath), type));
  }

  @action
  valueSchema(item) {
    switch (item?.type) {
      case "number":
        return { type: "number" };
      case "boolean":
        return { type: "boolean", ui: { expression: true } };
      case "array":
      case "object":
        return {
          type: "string",
          ui: {
            control: "code",
          },
          control_options: {
            height: 120,
            lang: "json",
          },
        };
      default:
        return { type: "string" };
    }
  }

  <template>
    <@form.Section @subtitle={{this.description}} @title={{this.label}}>
      <@form.Collection
        @name={{this.assignmentsPath}}
        @tagName="div"
        as |collection index item|
      >
        <div class="workflows-property-engine__collection-row">
          <DButton
            class="workflows-property-engine__collection-delete"
            @action={{fn this.removeAssignment collection.remove index}}
            @icon="xmark"
            @translatedAriaLabel={{i18n
              "discourse_workflows.property_engine.remove_assignment"
              name=item.name
            }}
            @translatedTitle={{i18n
              "discourse_workflows.property_engine.remove_assignment"
              name=item.name
            }}
          />

          <collection.Object
            class="workflows-property-engine__collection-fields"
            as |object|
          >
            <Field
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="name"
              @form={{object}}
              @formApi={{@formApi}}
              @label={{i18n
                "discourse_workflows.property_engine.assignment_name"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodes={{@nodes}}
              @nodeType={{@nodeType}}
              @nodeTypes={{@nodeTypes}}
              @schema={{this.nameSchema}}
              @session={{@session}}
            />

            <Field
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="type"
              @form={{object}}
              @formApi={{@formApi}}
              @label={{i18n
                "discourse_workflows.property_engine.assignment_type"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodes={{@nodes}}
              @nodeType={{@nodeType}}
              @nodeTypes={{@nodeTypes}}
              @onSet={{fn this.handleTypeChange index}}
              @schema={{this.typeSchema}}
              @session={{@session}}
            />

            <Field
              @configuration={{item}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="value"
              @form={{object}}
              @formApi={{@formApi}}
              @label={{i18n
                "discourse_workflows.property_engine.assignment_value"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodes={{@nodes}}
              @nodeType={{@nodeType}}
              @nodeTypes={{@nodeTypes}}
              @schema={{this.valueSchema item}}
              @session={{@session}}
            />
          </collection.Object>
        </div>
      </@form.Collection>

      <div class="workflows-property-engine__block-actions">
        <DButton
          class="btn-default workflows-property-engine__add-attrs-btn"
          @action={{this.addAssignment}}
          @icon="plus"
          @translatedLabel={{i18n
            "discourse_workflows.property_engine.add_field"
          }}
        />
      </div>
    </@form.Section>
  </template>
}
