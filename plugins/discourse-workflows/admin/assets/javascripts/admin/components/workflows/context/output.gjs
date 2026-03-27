import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { resolvePreviousOutput } from "./input";
import resolveNodeFields from "./resolve-node-fields";
import SchemaField from "./schema-field";

export default class OutputContext extends Component {
  get fields() {
    const nodeTypes = this.args.nodeTypes || [];
    const currentNode = this.args.node;
    const nodes = this.args.nodes || [];
    const connections = this.args.connections || [];
    const ownFields = resolveNodeFields(currentNode, nodeTypes) || [];

    if (currentNode.type?.startsWith("action:")) {
      return ownFields;
    }

    const previousFields = resolvePreviousOutput(
      currentNode,
      nodes,
      connections,
      nodeTypes
    );
    const ownKeys = new Set(ownFields.map((f) => f.key));
    const merged = previousFields.filter((f) => !ownKeys.has(f.key));
    merged.push(...ownFields);
    return merged;
  }

  <template>
    <div class="workflows-context-panel">
      <div class="workflows-context-panel__section">
        <h3 class="workflows-context-panel__title">
          {{i18n "discourse_workflows.configurator.output_context"}}{{icon
            "right-from-bracket"
          }}
        </h3>

        {{#if this.fields.length}}
          <ul class="workflows-schema-field-list">
            {{#each this.fields as |field|}}
              <SchemaField @field={{field}} />
            {{/each}}
          </ul>
        {{else}}
          <p class="workflows-context-panel__empty">
            {{i18n "discourse_workflows.configurator.no_output_context"}}
          </p>
        {{/if}}
      </div>
    </div>
  </template>
}
