// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
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

  <template>
    {{#if this.hasSelection}}
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
