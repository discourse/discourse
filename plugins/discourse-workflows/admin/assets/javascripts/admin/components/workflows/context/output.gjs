import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import processFields from "../../../lib/workflows/field-processors";
import { resolvePreviousOutput } from "../../../lib/workflows/graph-traversal";
import resolveNodeFields from "../../../lib/workflows/resolve-node-fields";
import SchemaField from "./schema-field";

export default class OutputContext extends Component {
  get graph() {
    return {
      nodes: this.args.nodes || [],
      connections: this.args.connections || [],
      nodeTypes: this.args.nodeTypes || [],
    };
  }

  get fields() {
    const currentNode = this.args.node;
    const configuration = this.args.configuration || currentNode.configuration;
    const ownFields =
      resolveNodeFields(currentNode, this.graph.nodeTypes, configuration) || [];

    let fields;
    if (currentNode.type?.startsWith("action:")) {
      fields = ownFields;
    } else {
      const previousFields = resolvePreviousOutput(currentNode, this.graph);
      const ownKeys = new Set(ownFields.map((f) => f.key));
      fields = previousFields.filter((f) => !ownKeys.has(f.key));
      fields.push(...ownFields);
    }

    return processFields(fields, currentNode, this.graph);
  }

  get needsExecutionDiscovery() {
    const type = this.args.node?.type;
    return type === "action:sql" || type === "action:code";
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
        {{else if this.needsExecutionDiscovery}}
          <p class="workflows-context-panel__empty">
            {{i18n
              "discourse_workflows.configurator.no_output_context_run_to_discover"
            }}
          </p>
        {{else}}
          <p class="workflows-context-panel__empty">
            {{i18n "discourse_workflows.configurator.no_output_context"}}
          </p>
        {{/if}}
      </div>
    </div>
  </template>
}
