import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import PagePickerModal from "../../components/editor/page-picker-modal";

/**
 * Adds a "Visual Editor" button next to the existing theme-show controls
 * (Preview / Export / Import). Clicking opens a modal that lets the admin
 * pick which page to land on; the modal navigates to that page with
 * `?ve_theme=<theme-id>` so the in-context pill auto-enters editor mode
 * bound to this theme.
 *
 * Hidden when:
 *   - the user isn't an admin (PluginOutlets render nothing for non-admins
 *     here anyway, but defense in depth),
 *   - the `visual_editor_enabled` site setting is off.
 */
export default class VisualEditorButton extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    if (!currentUser?.admin) {
      return false;
    }
    if (!siteSettings.visual_editor_enabled) {
      return false;
    }
    return true;
  }

  @service modal;

  @tracked isOpening = false;

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
      class="btn-default visual-editor-open-button"
      @icon="wand-magic-sparkles"
      @action={{this.openPagePicker}}
      @disabled={{this.isOpening}}
      @label="visual_editor.theme_admin.open_button"
      @title="visual_editor.theme_admin.open_button_title"
    />
    <span class="sr-only">{{i18n
        "visual_editor.theme_admin.open_button"
      }}</span>
  </template>
}
