// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import InspectorForm from "./inspector-form";

/**
 * Inspector for the selected block.
 *
 * Phase 2 surface: shows block name, namespace, container/leaf, description,
 * an editable args form (driven by FormKit and `schemaToFields`), and a
 * read-only conditions JSON for now. The conditions builder ships in Phase 6.
 */
export default class InspectorPanel extends Component {
  @service visualEditor;

  get hasSelection() {
    return this.visualEditor.selectedBlockData != null;
  }

  get data() {
    return this.visualEditor.selectedBlockData;
  }

  get metadata() {
    return this.data?.metadata ?? null;
  }

  /**
   * Whether the inspector should render the editable form. True if either
   * the block declared an `args` schema OR the layout passes any args at
   * runtime (in which case `InspectorForm` falls back to an inferred
   * schema). Blocks with no schema and no args still show "no arguments".
   */
  get hasArgsSchema() {
    const declaredArgs = this.metadata?.args;
    if (declaredArgs && Object.keys(declaredArgs).length > 0) {
      return true;
    }
    const liveArgs = this.data?.args;
    return !!(liveArgs && Object.keys(liveArgs).length > 0);
  }

  get hasConditions() {
    return this.data?.conditions != null;
  }

  get conditionsJson() {
    return JSON.stringify(this.data.conditions, null, 2);
  }

  /**
   * The selected block's soft-failure marker, read directly from the
   * entry's `__failureType` / `__failureReason` (set by the validator
   * when running in permissive mode). Drives the inline warning banner
   * and recovery action buttons.
   *
   * @returns {{failureType: string, failureReason: string}|null}
   */
  get failure() {
    return this.visualEditor.selectedBlockFailure;
  }

  @action
  removeSelectedBlock() {
    if (this.data?.key) {
      this.visualEditor.removeBlock(this.data.key);
    }
  }

  <template>
    {{#if this.hasSelection}}
      {{#if this.failure}}
        <div class="visual-editor-inspector-warning" role="alert">
          <span class="visual-editor-inspector-warning__header">
            {{dIcon "triangle-exclamation"}}
            <span>{{i18n "visual_editor.inspector.warning_header"}}</span>
          </span>
          {{#if this.failure.failureReason}}
            <p class="visual-editor-inspector-warning__reason">
              {{this.failure.failureReason}}
            </p>
          {{/if}}
          <div class="visual-editor-inspector-warning__actions">
            <button
              type="button"
              class="btn btn-danger"
              {{on "click" this.removeSelectedBlock}}
            >
              {{dIcon "trash-can"}}
              <span>{{i18n
                  "visual_editor.inspector.remove_block_action"
                }}</span>
            </button>
          </div>
        </div>
      {{/if}}

      <div class="visual-editor-inspector-section">
        <div class="inspector-section__title">
          {{i18n "visual_editor.inspector.section_metadata"}}
        </div>
        <div class="inspector-row">
          <span class="row-key">{{i18n
              "visual_editor.inspector.label_block_name"
            }}</span>
          <span>{{this.data.name}}</span>
        </div>
        {{#if this.metadata.namespace}}
          <div class="inspector-row">
            <span class="row-key">{{i18n
                "visual_editor.inspector.label_namespace"
              }}</span>
            <span>{{this.metadata.namespace}}</span>
          </div>
        {{/if}}
        {{#if this.metadata.description}}
          <div class="inspector-row">
            <span class="row-key">{{i18n
                "visual_editor.inspector.label_description"
              }}</span>
            <span>{{this.metadata.description}}</span>
          </div>
        {{/if}}
        <div class="inspector-row">
          <span class="row-key">{{i18n
              "visual_editor.inspector.label_is_container"
            }}</span>
          <span>{{if this.metadata.isContainer "yes" "no"}}</span>
        </div>
      </div>

      <div class="visual-editor-inspector-section">
        <div class="inspector-section__title">
          {{i18n "visual_editor.inspector.section_args"}}
        </div>
        {{#if this.hasArgsSchema}}
          <InspectorForm />
        {{else}}
          <div class="panel-empty">{{i18n
              "visual_editor.inspector.label_no_args"
            }}</div>
        {{/if}}
      </div>

      <div class="visual-editor-inspector-section">
        <div class="inspector-section__title">
          {{i18n "visual_editor.inspector.section_conditions"}}
        </div>
        {{#if this.hasConditions}}
          <pre>{{this.conditionsJson}}</pre>
        {{else}}
          <div class="panel-empty">{{i18n
              "visual_editor.inspector.label_no_conditions"
            }}</div>
        {{/if}}
      </div>
    {{else}}
      <div class="panel-empty">{{i18n "visual_editor.inspector.empty"}}</div>
    {{/if}}
  </template>
}
