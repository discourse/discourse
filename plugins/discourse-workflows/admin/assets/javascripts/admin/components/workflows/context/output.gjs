import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { outputSchemaForNode } from "../../../lib/workflows/data-schema";
import processFields from "../../../lib/workflows/field-processors";
import { nodeTypePorts } from "../../../lib/workflows/node-types";
import DragDropHint from "./drag-drop-hint";
import PinDataEditor from "./pin-data-editor";
import SchemaField from "./schema-field";

const VIEW_SCHEMA = "schema";
const VIEW_JSON = "json";

export default class OutputContext extends Component {
  @tracked viewMode = VIEW_SCHEMA;

  get nodeName() {
    return this.args.node?.name;
  }

  get isPinned() {
    return this.args.session?.isNodePinned(this.nodeName);
  }

  get pinnedItems() {
    return this.args.session?.pinnedItemsForNode(this.nodeName);
  }

  get singleOutputNode() {
    return (
      nodeTypePorts(this.args.node?.type, this.args.node?.typeVersion).length <=
      1
    );
  }

  get latestRunItems() {
    return this.args.session?.outputItemsForNode(this.args.node, 0);
  }

  // Items the JSON view should render: pinned if pinned, otherwise the latest
  // run's primary output, otherwise undefined.
  get effectiveItems() {
    return this.pinnedItems ?? this.latestRunItems;
  }

  // True when there's nothing to show in either view — no pinned data and no
  // run output. In that state we render a single full-height empty state
  // instead of duplicating it in both Schema and JSON views.
  get hasNoData() {
    return !this.pinnedItems && !this.latestRunItems;
  }

  get canPin() {
    return (
      this.singleOutputNode &&
      !this.isPinned &&
      Array.isArray(this.latestRunItems) &&
      this.latestRunItems.length > 0
    );
  }

  get canUnpin() {
    return this.isPinned;
  }

  get canEditPinData() {
    return this.singleOutputNode;
  }

  get showPinDataTip() {
    return this.canPin;
  }

  get isSchemaView() {
    return this.viewMode === VIEW_SCHEMA;
  }

  get isJsonView() {
    return this.viewMode === VIEW_JSON;
  }

  get graph() {
    return {
      nodes: this.args.nodes || [],
      connections: this.args.connections || [],
      nodeTypes: this.args.nodeTypes || [],
    };
  }

  get outputSchema() {
    const currentNode = this.args.node;
    const schema = outputSchemaForNode(
      this.args.session?.lastExecutionRunData || {},
      currentNode.name,
      { pinnedItems: this.pinnedItems, node: currentNode }
    );

    return {
      ...schema,
      itemCountLabel: this.itemCountLabel(schema.summary),
      emptyMessage: this.emptyMessage(schema.summary),
      fields: processFields(schema.fields, currentNode, this.graph),
    };
  }

  get fields() {
    return this.outputSchema.fields || [];
  }

  itemCountLabel(summary) {
    if (!summary?.itemCount) {
      return null;
    }

    return i18n("discourse_workflows.configurator.schema_item_count", {
      count: summary.itemCount,
    });
  }

  get singleItemCountLabel() {
    return this.outputSchema.itemCountLabel;
  }

  emptyMessage(summary) {
    if (!summary) {
      return i18n(
        "discourse_workflows.configurator.no_output_context_run_to_discover"
      );
    }

    if (summary.itemCount > 0) {
      return i18n("discourse_workflows.configurator.no_output_fields");
    }

    return i18n("discourse_workflows.configurator.no_output_context");
  }

  get emptyOutputMessage() {
    return this.outputSchema.emptyMessage;
  }

  @action
  switchView(viewMode) {
    this.viewMode = viewMode;
  }

  @action
  async togglePin() {
    try {
      if (this.isPinned) {
        await this.args.session.unpinNodeData(this.nodeName);
      } else if (this.canPin) {
        await this.args.session.pinNodeData(this.nodeName, this.latestRunItems);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get canTogglePin() {
    return this.singleOutputNode && (this.isPinned || this.canPin);
  }

  <template>
    <div class="workflows-context-panel">
      {{#if this.isPinned}}
        <div class="workflows-context-panel__pin-banner">
          {{dIcon "thumbtack"}}
          <span class="workflows-context-panel__pin-banner-text">
            {{i18n "discourse_workflows.pin_data.is_pinned"}}
          </span>
          <button
            type="button"
            class="btn-link workflows-context-panel__unpin-btn"
            {{on "click" this.togglePin}}
          >
            {{i18n "discourse_workflows.pin_data.unpin"}}
          </button>
        </div>
      {{/if}}

      {{#if this.showPinDataTip}}
        <DragDropHint
          @dismissKey="workflows-output-pin-tip-dismissed"
          @messageKey="discourse_workflows.pin_data.output_available_tip"
        />
      {{/if}}

      <div class="workflows-context-panel__section">
        <div class="workflows-context-panel__header">
          <h3 class="workflows-context-panel__title">
            {{i18n "discourse_workflows.configurator.output_context"}}{{dIcon
              "right-from-bracket"
            }}
            {{#if this.singleItemCountLabel}}
              <span class="workflows-context-panel__title-meta">
                {{this.singleItemCountLabel}}
              </span>
            {{/if}}
          </h3>

          {{#if this.singleOutputNode}}
            <div class="workflows-context-panel__header-actions">
              <div class="workflows-context-panel__tabs" role="tablist">
                <button
                  type="button"
                  role="tab"
                  aria-selected={{if this.isSchemaView "true" "false"}}
                  class={{dConcatClass
                    "workflows-context-panel__tab"
                    (if (eq this.viewMode "schema") "is-active")
                  }}
                  {{on "click" (fn this.switchView "schema")}}
                >{{i18n "discourse_workflows.pin_data.schema_view"}}</button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={{if this.isJsonView "true" "false"}}
                  class={{dConcatClass
                    "workflows-context-panel__tab"
                    (if (eq this.viewMode "json") "is-active")
                  }}
                  {{on "click" (fn this.switchView "json")}}
                >{{i18n "discourse_workflows.pin_data.json_view"}}</button>
              </div>

              <button
                type="button"
                class={{dConcatClass
                  "workflows-context-panel__icon-btn workflows-context-panel__pin-btn"
                  (if this.isPinned "is-pinned")
                }}
                disabled={{if this.canTogglePin false true}}
                title={{if
                  this.isPinned
                  (i18n "discourse_workflows.pin_data.unpin")
                  (i18n "discourse_workflows.pin_data.pin")
                }}
                aria-label={{if
                  this.isPinned
                  (i18n "discourse_workflows.pin_data.unpin")
                  (i18n "discourse_workflows.pin_data.pin")
                }}
                {{on "click" this.togglePin}}
              >
                {{dIcon "thumbtack"}}
              </button>
            </div>
          {{/if}}
        </div>

        {{#if this.hasNoData}}
          <PinDataEditor
            @nodeName={{this.nodeName}}
            @initialItems={{this.effectiveItems}}
            @canEdit={{this.canEditPinData}}
            @session={{@session}}
          />
        {{else if this.isJsonView}}
          <PinDataEditor
            @nodeName={{this.nodeName}}
            @initialItems={{this.effectiveItems}}
            @canEdit={{this.canEditPinData}}
            @session={{@session}}
          />
        {{else}}
          {{#if this.fields.length}}
            <ul class="workflows-schema-field-list">
              {{#each this.fields as |field|}}
                <SchemaField @field={{field}} />
              {{/each}}
            </ul>
          {{else}}
            <p class="workflows-context-panel__empty">
              {{this.emptyOutputMessage}}
            </p>
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
