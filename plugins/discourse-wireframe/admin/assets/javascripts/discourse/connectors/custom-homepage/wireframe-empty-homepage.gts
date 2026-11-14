import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import type WireframeWorkspaceService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-workspace";

interface WireframeEmptyHomepageSignature {
  /** Connector arguments supplied by the custom homepage outlet. */
  Args: {
    /** Arguments owned by the surrounding plugin outlet. */
    outletArgs: {
      /** Whether the homepage block outlet rendered any blocks. */
      hasBlocks?: boolean;
    };
  };
}

/**
 * Admin-only prompt shown on a custom homepage whose block outlet has nothing to
 * render and while the editor is closed. Styled after the editor's outlet frame
 * so it reads as the same surface the editor will open onto.
 */
export default class WireframeEmptyHomepage extends Component<WireframeEmptyHomepageSignature> {
  /** Owns editor permission and active state. */
  @service declare wireframeEditMode: WireframeEditModeService;

  /** Orchestrates entering the editor workspace. */
  @service declare wireframeWorkspace: WireframeWorkspaceService;

  get visible(): boolean {
    return (
      !this.args.outletArgs.hasBlocks &&
      this.wireframeEditMode.canEdit &&
      !this.wireframeEditMode.active
    );
  }

  @action
  openEditor(): void {
    this.wireframeWorkspace.enter();
  }

  <template>
    {{#if this.visible}}
      <section class="wireframe-empty-homepage">
        <header class="wireframe-empty-homepage__strip">
          <span class="wireframe-empty-homepage__name">
            {{dIcon "table-cells-large"}}
            {{i18n "wireframe.empty_homepage.outlet_name"}}
          </span>
          <span class="wireframe-empty-homepage__scope">
            {{i18n "wireframe.empty_homepage.admin_only"}}
          </span>
          <span class="wireframe-empty-homepage__status">
            {{dIcon "far-circle"}}
            {{i18n "wireframe.empty_homepage.status"}}
          </span>
        </header>
        <div class="wireframe-empty-homepage__body">
          <div class="wireframe-empty-homepage__empty">
            {{dIcon "table-cells-large" class="wireframe-empty-homepage__icon"}}
            <h2 class="wireframe-empty-homepage__title">
              {{i18n "wireframe.empty_homepage.title"}}
            </h2>
            <p class="wireframe-empty-homepage__description">
              {{i18n "wireframe.empty_homepage.description"}}
            </p>
            <div class="wireframe-empty-homepage__actions">
              <DButton
                class="btn-primary wireframe-empty-homepage__add"
                @action={{this.openEditor}}
                @label="wireframe.empty_homepage.start_building"
              />
            </div>
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}
