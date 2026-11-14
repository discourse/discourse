import Component from "@glimmer/component";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeWorkspaceService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-workspace";

/** The custom homepage route, the only page that renders the homepage outlet. */
const HOMEPAGE_ROUTE = "discovery.custom";

/**
 * Floating bottom-right pill that lets permitted users open the editor on the
 * homepage.
 *
 * Hidden when:
 *  - the user is not permitted (see `wireframeEditMode.canEdit`)
 *  - the page isn't the custom homepage (an outlet with a published layout is
 *    "editable" everywhere, so the route is what scopes the pill)
 *  - there are no editable outlets
 *  - the editor is already active
 */
export default class EntryPill extends Component {
  /** Names the current page. */
  @service declare router: RouterService;

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
    if (this.router.currentRouteName !== HOMEPAGE_ROUTE) {
      return false;
    }
    return this.wireframeLayoutQuery.editableOutlets.length > 0;
  }

  /** Enters the editor workspace. */
  @action
  enter(): void {
    this.wireframeWorkspace.enter();
  }

  <template>
    {{#if this.visible}}
      <DButton
        class="btn-primary wireframe-pill"
        @action={{this.enter}}
        @icon="pen-to-square"
        @label="wireframe.pill.enter"
      />
    {{/if}}
  </template>
}
