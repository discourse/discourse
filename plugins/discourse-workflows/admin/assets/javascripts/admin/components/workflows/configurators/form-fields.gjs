import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import {
  ChoiceList,
  FieldList,
} from "discourse/components/form-definition-editor";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import {
  emptyFixedCollectionItem,
  fieldVisible,
  fixedCollectionGroup,
  fixedCollectionRows,
  isExtraFieldShown,
  normalizeSchema,
  propertyDescription,
  propertyLabel,
} from "../../../lib/workflows/property-engine.js";
import Field from "./field.gjs";

const newChoice = () => ({ value: "" });

function optionLabel(choice) {
  const value = typeof choice === "object" ? choice?.value : choice;
  return String(value ?? "") || i18n("form_definition.untitled");
}

function fieldLabel(field) {
  return field.field_label || i18n("form_definition.untitled");
}

function isGrouped(collection) {
  return (
    collection != null &&
    typeof collection === "object" &&
    !Array.isArray(collection)
  );
}

// Bind to the saved shape so editing one row doesn't rewrite sibling fields or expressions.
function rowPath(collection, path, index) {
  const grouped = isGrouped(collection);
  const rows = grouped ? collection.values : collection;
  const parent = grouped ? `${path}.values` : path;
  return Array.isArray(rows) ? `${parent}.${index}` : parent;
}

function withRows(collection, rows) {
  if (collection == null || isGrouped(collection)) {
    return { ...collection, values: rows };
  }
  return rows;
}

class WorkflowChoices extends Component {
  get choices() {
    const options = this.args.field.options;
    return makeArray(isGrouped(options) ? options.values : options);
  }

  get path() {
    return `${this.args.path}.options`;
  }

  get valueSchema() {
    return fixedCollectionGroup(this.args.schema).values.value;
  }

  @action
  choiceBinding(choice, index) {
    const path = rowPath(this.args.field.options, this.path, index);
    if (choice && typeof choice === "object") {
      return { parent: path, name: "value" };
    }
    const lastDot = path.lastIndexOf(".");
    return { parent: path.slice(0, lastDot), name: path.slice(lastDot + 1) };
  }

  @action
  setChoices(choices) {
    return this.args.form.set(
      this.path,
      withRows(this.args.field.options, choices)
    );
  }

  <template>
    <ChoiceList
      @choices={{this.choices}}
      @form={{@form}}
      @labelFor={{optionLabel}}
      @newChoice={{newChoice}}
      @onChange={{this.setChoices}}
      @title={{@label}}
      as |choice index label|
    >
      {{#each
        (array (this.choiceBinding choice index)) key="parent"
        as |binding|
      }}
        <@form.Object @name={{binding.parent}} as |object|>
          <@Field
            @configuration={{choice}}
            @fieldName={{binding.name}}
            @form={{object}}
            @label={{label}}
            @schema={{this.valueSchema}}
          />
        </@form.Object>
      {{/each}}
    </ChoiceList>
  </template>
}

class WorkflowFormField extends Component {
  @tracked explicit = new Set();

  get canSetRequired() {
    return (
      this.args.requiredSchema &&
      fieldVisible(this.args.requiredSchema, this.args.field)
    );
  }

  get optionalAttributes() {
    return this.args.properties.filter(
      (property) =>
        !property.required && fieldVisible(property, this.args.field)
    );
  }

  @action
  isActive(property) {
    return isExtraFieldShown(property, this.args.field, this.explicit);
  }

  @action
  toggle(property) {
    const next = new Set(this.explicit);
    if (this.isActive(property)) {
      next.delete(property.name);
      this.args.form.set(
        `${this.args.path}.${property.name}`,
        property.default ?? ""
      );
    } else {
      next.add(property.name);
    }
    this.explicit = next;
  }

  <template>
    {{#each (array @path) as |path|}}
      <@form.Object @name={{path}} as |object|>
        <@Header
          @onSetRequired={{if
            this.canSetRequired
            (fn @form.set (concat path ".required"))
          }}
          @required={{@field.required}}
          as |Attribute|
        >
          {{#each this.optionalAttributes key="name" as |property|}}
            <Attribute
              data-field-attribute={{property.name}}
              @active={{this.isActive property}}
              @label={{propertyLabel @nodeDefinition property.name}}
              @onToggle={{fn this.toggle property}}
            />
          {{/each}}
        </@Header>
        {{#each @properties key="name" as |property|}}
          {{#if (or property.required (this.isActive property))}}
            {{#if (eq property.type "fixed_collection")}}
              <WorkflowChoices
                @field={{@field}}
                @Field={{@Field}}
                @form={{@form}}
                @label={{propertyLabel @nodeDefinition property.name}}
                @path={{path}}
                @schema={{property}}
              />
            {{else}}
              <@Field
                @configuration={{@field}}
                @fieldName={{property.name}}
                @form={{object}}
                @schema={{property}}
              />
            {{/if}}
          {{/if}}
        {{/each}}
      </@form.Object>
    {{/each}}
  </template>
}

export default class FormFields extends Component {
  get collection() {
    return this.args.configuration[this.args.fieldName];
  }

  get fields() {
    return fixedCollectionRows(this.collection);
  }

  get group() {
    return fixedCollectionGroup(this.args.schema);
  }

  get properties() {
    return normalizeSchema(this.group.values).filter(
      (property) => property.name !== "required"
    );
  }

  @action
  setFields(fields) {
    this.args.form.set(this.args.fieldName, withRows(this.collection, fields));
  }

  <template>
    <@form.Section
      @subtitle={{propertyDescription @nodeDefinition @fieldName}}
      @title={{propertyLabel @nodeDefinition @fieldName}}
    >
      <FieldList
        @fields={{this.fields}}
        @form={{@form}}
        @inlineMenus={{true}}
        @labelFor={{fieldLabel}}
        @newField={{fn emptyFixedCollectionItem this.group}}
        @onChange={{this.setFields}}
        as |field index Header|
      >
        <WorkflowFormField
          @field={{field}}
          @Field={{component
            Field
            connections=@connections
            credentials=@credentials
            formApi=@formApi
            node=@node
            nodeDefinition=@nodeDefinition
            nodeParameters=@nodeParameters
            nodes=@nodes
            nodeType=@nodeType
            nodeTypes=@nodeTypes
            session=@session
          }}
          @form={{@form}}
          @Header={{Header}}
          @nodeDefinition={{@nodeDefinition}}
          @path={{rowPath this.collection @fieldName index}}
          @properties={{this.properties}}
          @requiredSchema={{this.group.values.required}}
        />
      </FieldList>
    </@form.Section>
  </template>
}
