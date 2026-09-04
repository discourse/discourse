import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeWorkspaceService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-workspace";

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
  /** Orchestrates entering the editor workspace. */
  @service declare wireframeWorkspace: WireframeWorkspaceService;
  /** Exposes editable outlets on the current page. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  /** Owns editor permission and active state. */
  @service declare wireframeEditMode: WireframeEditModeService;

  /** Whether the entry affordance should be rendered. */
  get visible(): boolean {
    if (!this.wireframeEditMode.canEdit) {
      return false;
    }
    if (this.wireframeEditMode.active) {
      return false;
    }
    return this.wireframeLayoutQuery.editableOutlets.length > 0;
  }

  /** Translated label including the editable-outlet count. */
  get label(): string {
    const count = this.wireframeLayoutQuery.editableOutlets.length;
    return i18n("wireframe.pill.enter_with_count", { count });
  }

  /** Enters the editor workspace. */
  @action
  enter(): void {
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
