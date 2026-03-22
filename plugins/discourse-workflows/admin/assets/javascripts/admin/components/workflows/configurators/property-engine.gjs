import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import {
  fieldControl,
  fieldVisible,
  findNodeType,
  normalizeSchema,
} from "../../../lib/workflows/property-engine";
import PropertyEngineCollection from "./property-engine-collection";
import PropertyEngineField from "./property-engine-field";

function isVisible(field, configuration) {
  return fieldVisible(field, configuration || {});
}

export default class PropertyEngineConfigurator extends Component {
  get allFields() {
    return normalizeSchema(this.args.schema);
  }

  get nodeType() {
    return this.args.nodeType || this.args.node?.type;
  }

  get nodeDefinition() {
    return (
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.nodeType)
    );
  }

  get metadata() {
    return this.nodeDefinition?.metadata || {};
  }

  <template>
    {{#each this.allFields key="name" as |field|}}
      {{#if (isVisible field @configuration)}}
        {{#if (eq (fieldControl field) "collection")}}
          <PropertyEngineCollection
            @form={{@form}}
            @formApi={{@formApi}}
            @fieldName={{field.name}}
            @nodeDefinition={{this.nodeDefinition}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{@nodeTypes}}
            @schema={{field}}
          />
        {{else}}
          <PropertyEngineField
            @form={{@form}}
            @formApi={{@formApi}}
            @configuration={{@configuration}}
            @connections={{@connections}}
            @fieldName={{field.name}}
            @metadata={{this.metadata}}
            @node={{@node}}
            @nodeDefinition={{this.nodeDefinition}}
            @nodes={{@nodes}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{@nodeTypes}}
            @schema={{field}}
          />
        {{/if}}
      {{/if}}
    {{/each}}
  </template>
}
