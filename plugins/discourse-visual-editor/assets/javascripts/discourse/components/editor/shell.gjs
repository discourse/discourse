// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import InspectorPanel from "./inspector-panel";
import OutlinePanel from "./outline-panel";

/**
 * The 3-pane editor chrome (toolbar + outline + canvas + inspector).
 *
 * Mounted by the api-initializer when the editor is active. The canvas region
 * is intentionally a `pointer-events: none` placeholder — the live page
 * underneath handles all clicks; only block-chrome wrappers and the panels
 * receive editor input.
 */
export default class EditorShell extends Component {
  @service visualEditor;

  @action
  exit() {
    this.visualEditor.exit();
  }

  <template>
    {{#if this.visualEditor.isActive}}
      <div class="visual-editor-shell">
        <div class="visual-editor-toolbar">
          <div class="toolbar-left">
            {{icon "wand-magic-sparkles"}}
            <span class="toolbar-title">Visual Editor</span>
          </div>
          <div class="toolbar-right">
            <button
              type="button"
              class="btn btn-default"
              {{on "click" this.exit}}
            >
              {{icon "xmark"}}
              <span>{{i18n "visual_editor.chrome.exit"}}</span>
            </button>
          </div>
        </div>

        <div class="visual-editor-panel --left">
          <div class="panel-header">{{i18n
              "visual_editor.chrome.panel_outline"
            }}</div>
          <div class="panel-body">
            <OutlinePanel />
          </div>
        </div>

        <div class="visual-editor-canvas"></div>

        <div class="visual-editor-panel --right">
          <div class="panel-header">{{i18n
              "visual_editor.chrome.panel_inspector"
            }}</div>
          <div class="panel-body">
            <InspectorPanel />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
