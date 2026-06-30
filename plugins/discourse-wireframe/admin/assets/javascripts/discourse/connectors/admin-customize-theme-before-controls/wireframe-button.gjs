import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PagePickerModal from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/page-picker-modal";

/**
 * Adds a "Wireframe" button next to the existing theme-show controls
 * (Preview / Export / Import). Clicking opens a modal that lets the admin
 * pick which page to land on; the modal navigates to that page with
 * `?wf_theme=<theme-id>` so the in-context pill auto-enters editor mode
 * bound to this theme.
 *
 * Hidden when:
 *   - the user isn't an admin (PluginOutlets render nothing for non-admins
 *     here anyway, but defense in depth),
 *   - the `wireframe_enabled` site setting is off.
 */
export default class WireframeButton extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    if (!currentUser?.admin) {
      return false;
    }
    if (!siteSettings.wireframe_enabled) {
      return false;
    }
    return true;
  }

  @service modal;

  @tracked isOpening = false;

  /**
   * Opens the page-picker modal so the admin can choose which page to
   * launch the wireframe editor on. The modal is responsible for the
   * eventual navigation; this action only flips the loading flag.
   */
  @action
  async openPagePicker() {
    this.isOpening = true;
    try {
      await this.modal.show(PagePickerModal, {
        model: { theme: this.args.outletArgs.theme },
      });
    } finally {
      this.isOpening = false;
    }
  }

  <template>
    <DButton
      class="btn-default wireframe-open-button"
      @icon="wand-magic-sparkles"
      @action={{this.openPagePicker}}
      @disabled={{this.isOpening}}
      @label="wireframe.theme_admin.open_button"
      @title="wireframe.theme_admin.open_button_title"
    />
    <span class="sr-only">{{i18n "wireframe.theme_admin.open_button"}}</span>
  </template>
}
