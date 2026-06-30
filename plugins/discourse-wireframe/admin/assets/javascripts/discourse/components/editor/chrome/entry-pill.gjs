// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Floating bottom-right pill that lets permitted users open the editor on
 * pages with at least one Block Outlet.
 *
 * Hidden when:
 *  - the user is not permitted (see `wireframeEditMode.canEdit`)
 *  - there are no editable outlets on this page
 *  - the editor is already active
 */
export default class EntryPill extends Component {
  @service wireframeWorkspace;
  @service wireframeLayoutQuery;
  @service wireframeEditMode;

  get visible() {
    if (!this.wireframeEditMode.canEdit) {
      return false;
    }
    if (this.wireframeEditMode.active) {
      return false;
    }
    return this.wireframeLayoutQuery.editableOutlets.length > 0;
  }

  get label() {
    const count = this.wireframeLayoutQuery.editableOutlets.length;
    return i18n("wireframe.pill.enter_with_count", { count });
  }

  @action
  enter() {
    this.wireframeWorkspace.enter();
  }

  <template>
    {{#if this.visible}}
      <DButton
        class="wireframe-pill"
        @icon="wand-magic-sparkles"
        @translatedLabel={{this.label}}
        @action={{this.enter}}
      />
    {{/if}}
  </template>
}
