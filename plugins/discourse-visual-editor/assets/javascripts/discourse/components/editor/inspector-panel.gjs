// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

/**
 * Read-only inspector for the selected block.
 *
 * Phase 1 surface: shows block name, namespace, container/leaf, description,
 * args (current values + schema), conditions tree (raw JSON for now). Editing,
 * FormKit-driven controls, and condition builder ship in Phase 2 and Phase 6.
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

  get hasArgs() {
    return this.data?.args && Object.keys(this.data.args).length > 0;
  }

  get hasArgsSchema() {
    return this.metadata?.args && Object.keys(this.metadata.args).length > 0;
  }

  get hasConditions() {
    return this.data?.conditions != null;
  }

  get conditionsJson() {
    return JSON.stringify(this.data.conditions, null, 2);
  }

  get argsSchemaJson() {
    return JSON.stringify(this.metadata.args, null, 2);
  }

  get argsJson() {
    return JSON.stringify(this.data.args, null, 2);
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
        {{#if this.hasArgs}}
          <pre>{{this.argsJson}}</pre>
        {{else}}
          <div class="panel-empty">{{i18n
              "visual_editor.inspector.label_no_args"
            }}</div>
        {{/if}}
        {{#if this.hasArgsSchema}}
          <div class="inspector-row">
            <span class="row-key">{{i18n
                "visual_editor.inspector.label_args_schema"
              }}</span>
          </div>
          <pre>{{this.argsSchemaJson}}</pre>
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
