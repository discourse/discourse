import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CONTROL_REGISTRY from "../../../lib/workflows/control-registry";
import { resolveNodeTypeVersion } from "../../../lib/workflows/node-types";
import {
  credentialSlotAnchorField,
  credentialSlotVisible,
  credentialTypesForSlot,
  fieldControl,
  fieldVisible,
  findNodeType,
  normalizeSchema,
} from "../../../lib/workflows/property-engine";
import CredentialControl from "./credential";
import Field from "./field";

function credentialSlotLabel(slot) {
  return i18n(slot.label_key || "discourse_workflows.credentials.type");
}

export default class PropertyEngineConfigurator extends Component {
  get allFields() {
    return normalizeSchema(this.args.schema);
  }

  get nodeType() {
    return this.args.nodeType || this.args.node?.type;
  }

  get nodeDefinition() {
    const definition =
      this.args.nodeDefinition ||
      findNodeType(this.args.nodeTypes, this.nodeType);

    return resolveNodeTypeVersion(definition, this.args.node?.typeVersion);
  }

  get metadata() {
    return this.nodeDefinition?.metadata || {};
  }

  get nodeParameters() {
    return this.args.nodeParameters || this.args.configuration || {};
  }

  get credentialSlotsByAnchor() {
    const map = new Map();
    for (const slot of this.args.credentialSlots || []) {
      const anchor = credentialSlotAnchorField(slot);
      if (!anchor) {
        continue;
      }
      if (!map.has(anchor)) {
        map.set(anchor, []);
      }
      map.get(anchor).push(slot);
    }
    return map;
  }

  @action
  slotsForField(fieldName) {
    return this.credentialSlotsByAnchor.get(fieldName) || [];
  }

  @action
  controlEntry(field) {
    return CONTROL_REGISTRY[fieldControl(field)] || CONTROL_REGISTRY.default;
  }

  <template>
    {{#each this.allFields key="name" as |field|}}
      {{#if (fieldVisible field @configuration)}}
        {{#let (this.controlEntry field) as |entry|}}
          {{#if (eq entry.kind "structural")}}
            <entry.renderer
              @form={{@form}}
              @formApi={{@formApi}}
              @configuration={{@configuration}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName={{field.name}}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{this.nodeParameters}}
              @nodeType={{this.nodeType}}
              @nodes={{@nodes}}
              @nodeTypes={{@nodeTypes}}
              @schema={{field}}
              @session={{@session}}
              @onChange={{@onChange}}
              @onBeforeStartTestSession={{@onBeforeStartTestSession}}
            />
          {{else}}
            <Field
              @form={{@form}}
              @formApi={{@formApi}}
              @configuration={{@configuration}}
              @connections={{@connections}}
              @credentials={{@credentials}}
              @fieldName={{field.name}}
              @metadata={{this.metadata}}
              @node={{@node}}
              @nodeDefinition={{this.nodeDefinition}}
              @nodeParameters={{this.nodeParameters}}
              @nodes={{@nodes}}
              @nodeType={{this.nodeType}}
              @nodeTypes={{@nodeTypes}}
              @schema={{field}}
              @session={{@session}}
              @onBeforeStartTestSession={{@onBeforeStartTestSession}}
            />
          {{/if}}
        {{/let}}
        {{#each (this.slotsForField field.name) as |slot|}}
          {{#if (credentialSlotVisible slot @configuration)}}
            <CredentialControl
              @credentialTypes={{credentialTypesForSlot slot}}
              @label={{credentialSlotLabel slot}}
              @onChange={{fn @onCredentialSet slot.name}}
              @value={{@credentialValue slot.name}}
            />
          {{/if}}
        {{/each}}
      {{/if}}
    {{/each}}
  </template>
}
