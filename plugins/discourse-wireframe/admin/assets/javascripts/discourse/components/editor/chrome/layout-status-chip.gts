import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type DialogService from "discourse/dialog-holder/services/dialog";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import type WireframeDraftPreviewService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-draft-preview";
import WireframeLayoutStatusService, {
  LayoutStatus,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-status";
import type WireframePublishTargetService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";

const STATUSES: readonly LayoutStatus[] = ["draft", "published"];

/**
 * The layout's Draft or Published status, next to its name in the header. Its
 * menu changes the status right away; saving is a separate action, so changing
 * the status never saves and saving never changes it.
 */
export default class LayoutStatusChip extends Component {
  @service declare dialog: DialogService;
  @service declare wireframeDraftPreview: WireframeDraftPreviewService;
  @service declare wireframeLayoutStatus: WireframeLayoutStatusService;

  @service declare wireframePublishTarget: WireframePublishTargetService;

  statuses = STATUSES;

  isCurrent = (status: LayoutStatus): boolean => status === this.status;

  isDisabled = (status: LayoutStatus): boolean =>
    status === "published" && !this.wireframeLayoutStatus.canPublish;

  /** Where to see the saved layout on the live site, once it exists. */
  get previewUrl(): string | null {
    const id = this.wireframePublishTarget.activeThemeId;
    return this.status === "draft" &&
      this.wireframePublishTarget.hasDesign &&
      id
      ? this.wireframeDraftPreview.urlFor(id)
      : null;
  }

  get status(): LayoutStatus {
    return this.wireframeLayoutStatus.status;
  }

  get label(): string {
    return i18n(`wireframe.status.${this.status}`);
  }

  get ariaLabel(): string {
    return i18n("wireframe.status.chip_label", { status: this.label });
  }

  @action
  async openPreview(close: () => Promise<void>): Promise<void> {
    await close();
    if (this.previewUrl) {
      window.open(this.previewUrl, "_blank", "noopener");
    }
  }

  @action
  async pick(status: LayoutStatus, close: () => Promise<void>): Promise<void> {
    await close();
    const error = await this.wireframeLayoutStatus.setStatus(status);
    if (error) {
      this.dialog.alert(error);
    }
  }

  <template>
    <DMenu
      aria-haspopup="menu"
      aria-label={{this.ariaLabel}}
      @identifier="wireframe-layout-status"
      @placement="bottom-start"
      @triggerClass={{dConcatClass
        "wireframe-status-chip"
        (concat "--" this.status)
      }}
    >
      <:trigger>
        <span aria-hidden="true" class="wireframe-status-chip__dot"></span>
        <span class="wireframe-status-chip__label">{{this.label}}</span>
        {{dIcon "chevron-down"}}
      </:trigger>
      <:content as |menu|>
        <div class="wireframe-status-menu">
          <DDropdownMenu as |dropdown|>
            {{#each this.statuses as |status|}}
              <dropdown.item>
                <DButton
                  aria-current={{if (this.isCurrent status) "true"}}
                  class={{dConcatClass
                    "btn-transparent wireframe-status-menu__item"
                    (concat "--" status)
                  }}
                  disabled={{this.isDisabled status}}
                  @action={{fn this.pick status menu.close}}
                  @icon={{if (this.isCurrent status) "check" "empty"}}
                  @translatedLabel={{i18n (concat "wireframe.status." status)}}
                  @translatedTitle={{i18n
                    (concat "wireframe.status." status "_hint")
                  }}
                />
              </dropdown.item>
            {{/each}}
            {{#if this.previewUrl}}
              <dropdown.divider />
              <dropdown.item>
                <DButton
                  class="btn-transparent wireframe-status-menu__preview"
                  @action={{fn this.openPreview menu.close}}
                  @icon="eye"
                  @label="wireframe.preview.action"
                />
              </dropdown.item>
            {{/if}}
          </DDropdownMenu>
          {{#if this.wireframeLayoutStatus.hasUnsavedChanges}}
            <p class="wireframe-status-menu__note">{{i18n
                "wireframe.status.unsaved_note"
              }}</p>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}
