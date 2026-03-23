import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { loadNodeTypes } from "../../../lib/workflows/node-types";

export default class VariablePicker extends Component {
  @tracked variables = [];

  constructor() {
    super(...arguments);
    this.#loadVariables();
  }

  async #loadVariables() {
    const nodeTypes = await loadNodeTypes();
    const variables = [];

    const triggerType = nodeTypes.find(
      (nt) => nt.identifier === this.args.triggerType
    );

    if (triggerType?.output_schema) {
      for (const key of Object.keys(triggerType.output_schema)) {
        variables.push({
          id: `trigger.${key}`,
          name: i18n(`discourse_workflows.if_condition.fields.trigger_${key}`, {
            defaultValue: key.replace(/_/g, " "),
          }),
        });
      }
    }

    const nodes = this.args.nodes || [];
    for (const node of nodes) {
      if (!node.type?.startsWith("action:")) {
        continue;
      }
      const nodeType = nodeTypes.find((nt) => nt.identifier === node.type);
      if (!nodeType?.output_schema) {
        continue;
      }
      const nodeLabel = i18n(`discourse_workflows.nodes.${node.type}`, {
        defaultValue: node.type,
      });
      for (const key of Object.keys(nodeType.output_schema)) {
        variables.push({
          id: `${node.name}.${key}`,
          name: `${nodeLabel} — ${key.replace(/_/g, " ")}`,
        });
      }
    }

    try {
      const varsResult = await ajax(
        "/admin/plugins/discourse-workflows/variables.json"
      );
      for (const v of varsResult.variables) {
        variables.push({
          id: `$vars.${v.key}`,
          name: `${i18n("discourse_workflows.variables.title")} — ${v.key}`,
        });
      }
    } catch {
      // skip if unavailable
    }

    this.variables = variables;
  }

  @action
  selectVariable(variable, closeFn) {
    this.args.onSelect(`{{ ${variable.id} }}`);
    closeFn();
  }

  <template>
    <DMenu
      @identifier="workflows-variable-picker"
      @icon="plus"
      @inline={{true}}
      class="btn-icon-text workflows-variable-picker__trigger"
    >
      <:content as |args|>
        <DropdownMenu as |dropdown|>
          {{#each this.variables as |variable|}}
            <dropdown.item>
              <DButton
                @action={{fn this.selectVariable variable args.close}}
                @translatedLabel={{variable.name}}
                class="btn-transparent"
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
