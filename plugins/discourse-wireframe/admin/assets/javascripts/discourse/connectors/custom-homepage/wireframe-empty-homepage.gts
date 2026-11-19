import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import type WireframeDraftPreviewService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-draft-preview";
import type WireframeDraftsService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drafts";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import type WireframePublishTargetService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";
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

  /** Finds the theme's saved layouts. */
  @service declare wireframeDrafts: WireframeDraftsService;

  /** Builds the preview link. */
  @service declare wireframeDraftPreview: WireframeDraftPreviewService;

  /** Resolves the theme in use. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** A saved layout the theme doesn't use yet, if one exists. */
  @tracked unpublished: { id: number; name: string } | null = null;

  constructor(owner: unknown, args: WireframeEmptyHomepageSignature["Args"]) {
    super(owner as never, args);
    this.#findUnpublished();
  }

  get previewUrl(): string | null {
    return this.unpublished
      ? this.wireframeDraftPreview.urlFor(this.unpublished.id)
      : null;
  }

  get visible(): boolean {
    return (
      !this.args.outletArgs.hasBlocks &&
      this.wireframeEditMode.canEdit &&
      !this.wireframeEditMode.active
    );
  }

  @action
  preview(): void {
    if (this.previewUrl) {
      window.location.assign(this.previewUrl);
    }
  }

  @action
  openEditor(): void {
    this.wireframeWorkspace.enter();
  }

  async #findUnpublished(): Promise<void> {
    const themeId = this.wireframePublishTarget.parentThemeId;
    if (themeId == null || !this.wireframeEditMode.canEdit) {
      return;
    }
    const { installedId, currentId, designs } =
      await this.wireframeDrafts.fetchDesigns(themeId);
    const design = designs.find((d) => d.id === currentId);
    if (design && currentId !== installedId) {
      this.unpublished = { id: design.id, name: design.name };
    }
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
              {{#if this.unpublished}}
                {{i18n "wireframe.empty_homepage.unpublished_title"}}
              {{else}}
                {{i18n "wireframe.empty_homepage.title"}}
              {{/if}}
            </h2>
            <p class="wireframe-empty-homepage__description">
              {{#if this.unpublished}}
                {{i18n
                  "wireframe.empty_homepage.unpublished"
                  name=this.unpublished.name
                }}
              {{else}}
                {{i18n "wireframe.empty_homepage.description"}}
              {{/if}}
            </p>
            <div class="wireframe-empty-homepage__actions">
              {{#if this.previewUrl}}
                <DButton
                  class="btn-default wireframe-empty-homepage__preview"
                  @action={{this.preview}}
                  @icon="eye"
                  @label="wireframe.preview.action"
                />
              {{/if}}
              <DButton
                class="btn-primary wireframe-empty-homepage__add"
                @action={{this.openEditor}}
                @label={{if
                  this.unpublished
                  "wireframe.empty_homepage.edit_unpublished"
                  "wireframe.empty_homepage.start_building"
                }}
              />
            </div>
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}
