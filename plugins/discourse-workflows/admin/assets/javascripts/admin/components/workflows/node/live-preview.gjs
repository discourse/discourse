import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";
import { findNodeType } from "../../../lib/workflows/property-engine";

const DEBOUNCE_MS = 400;
const MAX_CELL_LENGTH = 80;

function cellValue(value) {
  if (value === null || value === undefined) {
    return "";
  }

  if (Array.isArray(value)) {
    const scalars = value.every((entry) => typeof entry !== "object");
    if (scalars) {
      return value.join(", ").slice(0, MAX_CELL_LENGTH);
    }
    return i18n("discourse_workflows.node_preview.nested_items", {
      count: value.length,
    });
  }

  if (typeof value === "object") {
    return JSON.stringify(value).slice(0, MAX_CELL_LENGTH);
  }

  return String(value).slice(0, MAX_CELL_LENGTH);
}

export default class LivePreview extends Component {
  @tracked loading = false;
  @tracked result = null;
  @tracked error = null;

  get nodeDefinition() {
    return findNodeType(this.args.nodeTypes, this.args.node?.type);
  }

  get previewable() {
    return this.nodeDefinition?.previewable === true;
  }

  get items() {
    return this.result?.outputs?.[0] ?? [];
  }

  get columns() {
    const keys = [];
    for (const item of this.items) {
      for (const key of Object.keys(item?.json ?? {})) {
        if (!keys.includes(key)) {
          keys.push(key);
        }
      }
    }
    return keys;
  }

  get rows() {
    return this.items.map((item) =>
      this.columns.map((key) => cellValue(item?.json?.[key]))
    );
  }

  get countLabel() {
    return i18n("discourse_workflows.node_preview.counts", {
      input: i18n("discourse_workflows.node_preview.items", {
        count: this.result?.input_count ?? 0,
      }),
      output: i18n("discourse_workflows.node_preview.items", {
        count: this.items.length,
      }),
    });
  }

  get emptyReason() {
    if (this.error) {
      return this.error;
    }
    if (!this.result) {
      return null;
    }
    if (!this.result.input_count) {
      return i18n("discourse_workflows.node_preview.pending");
    }
    if (!this.items.length) {
      return i18n("discourse_workflows.node_preview.no_items");
    }
    return null;
  }

  @action
  schedulePreview() {
    if (!this.previewable) {
      return;
    }

    discourseDebounce(this, this.loadPreview, DEBOUNCE_MS);
  }

  @action
  async loadPreview() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const workflowId = this.args.session?.workflowId;
    const nodeId = this.args.node?.clientId;

    if (!workflowId || !nodeId) {
      return;
    }

    this.loading = true;

    try {
      this.result = await ajax(
        "/admin/plugins/discourse-workflows/node-previews.json",
        {
          type: "POST",
          contentType: "application/json",
          data: JSON.stringify({
            workflow_id: workflowId,
            node_id: nodeId,
            parameters: this.args.configuration || {},
          }),
        }
      );
      this.error = this.result?.error || null;
    } catch {
      this.result = null;
      this.error = i18n("discourse_workflows.node_preview.failed");
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if this.previewable}}
      <div
        class="workflows-node-preview workflows-context-panel__section"
        {{didInsert this.schedulePreview}}
        {{didUpdate this.schedulePreview @configuration}}
      >
        <div class="workflows-context-panel__header">
          <h3 class="workflows-context-panel__title">
            {{i18n "discourse_workflows.node_preview.title"}}
            {{#if this.result}}
              <span class="workflows-context-panel__title-meta">
                {{this.countLabel}}
              </span>
            {{/if}}
          </h3>
        </div>

        {{#if this.emptyReason}}
          <p class="workflows-context-panel__empty">{{this.emptyReason}}</p>
        {{else if this.columns.length}}
          <div class="workflows-node-preview__table-wrapper">
            <table class="workflows-node-preview__table">
              <thead>
                <tr>
                  {{#each this.columns as |column|}}
                    <th>{{column}}</th>
                  {{/each}}
                </tr>
              </thead>
              <tbody>
                {{#each this.rows as |row|}}
                  <tr>
                    {{#each row as |cell|}}
                      <td>{{cell}}</td>
                    {{/each}}
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>

          {{#if this.result.truncated}}
            <p class="workflows-node-preview__truncated">
              {{i18n "discourse_workflows.node_preview.truncated"}}
            </p>
          {{/if}}
        {{else}}
          <p class="workflows-context-panel__empty">
            {{i18n "discourse_workflows.node_preview.pending"}}
          </p>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
