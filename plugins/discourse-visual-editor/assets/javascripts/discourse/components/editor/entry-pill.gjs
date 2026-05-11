// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Floating bottom-right pill that lets permitted users open the editor on
 * pages with at least one Block Outlet.
 *
 * Hidden when:
 *  - the user is not permitted (see `visualEditor.canEdit`)
 *  - there are no editable outlets on this page
 *  - the editor is already active
 */
export default class EntryPill extends Component {
  @service visualEditor;

  get visible() {
    if (!this.visualEditor.canEdit) {
      return false;
    }
    if (this.visualEditor.isActive) {
      return false;
    }
    return this.visualEditor.editableOutlets.length > 0;
  }

  get label() {
    const count = this.visualEditor.editableOutlets.length;
    return i18n("visual_editor.pill.enter_with_count", { count });
  }

  @action
  enter() {
    this.visualEditor.enter();
  }

  <template>
    {{#if this.visible}}
      <button
        type="button"
        class="visual-editor-pill"
        {{on "click" this.enter}}
      >
        {{dIcon "wand-magic-sparkles"}}
        <span>{{this.label}}</span>
      </button>
    {{/if}}
  </template>
}
