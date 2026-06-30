import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  findNodeType,
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
  valueSchema(item) {
    switch (item?.type) {
      case "number":
        return { type: "number" };
      case "boolean":
        return { type: "boolean" };
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
    <@form.Section @title={{this.label}} @subtitle={{this.description}}>
      <@form.Collection
        @name={{this.assignmentsPath}}
        @tagName="div"
        as |collection index item|
      >
        <div class="workflows-property-engine__collection-row">
          <DButton
            @action={{fn this.removeAssignment collection.remove index}}
            @icon="xmark"
            class="workflows-property-engine__collection-delete"
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
              @form={{object}}
              @formApi={{@formApi}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="name"
              @label={{i18n
                "discourse_workflows.property_engine.assignment_name"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodeType={{@nodeType}}
              @nodes={{@nodes}}
              @nodeTypes={{@nodeTypes}}
              @schema={{this.nameSchema}}
              @session={{@session}}
            />

            <Field
              @form={{object}}
              @formApi={{@formApi}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="type"
              @label={{i18n
                "discourse_workflows.property_engine.assignment_type"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodeType={{@nodeType}}
              @nodes={{@nodes}}
              @nodeTypes={{@nodeTypes}}
              @schema={{this.typeSchema}}
              @session={{@session}}
            />

            <Field
              @form={{object}}
              @formApi={{@formApi}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName="value"
              @label={{i18n
                "discourse_workflows.property_engine.assignment_value"
              }}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{@nodeParameters}}
              @nodeType={{@nodeType}}
              @nodes={{@nodes}}
              @nodeTypes={{@nodeTypes}}
              @schema={{this.valueSchema item}}
              @session={{@session}}
            />
          </collection.Object>
        </div>
      </@form.Collection>

      <div class="workflows-property-engine__block-actions">
        <DButton
          @action={{this.addAssignment}}
          @icon="plus"
          @translatedLabel={{i18n
            "discourse_workflows.property_engine.add_field"
          }}
          class="btn-default workflows-property-engine__add-attrs-btn"
        />
      </div>
    </@form.Section>
  </template>
}
