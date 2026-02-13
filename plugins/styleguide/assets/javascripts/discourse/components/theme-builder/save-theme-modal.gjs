import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class SaveThemeModal extends Component {
  @service themeBuilderState;

  @tracked themeName = "";
  @tracked isSaving = false;

  get isDisabled() {
    return !this.themeName.trim() || this.isSaving;
  }

  @action
  updateName(event) {
    this.themeName = event.target.value;
  }

  @action
  async save() {
    if (!this.themeName.trim() || this.isSaving) {
      return;
    }

    this.isSaving = true;
    try {
      await this.themeBuilderState.saveAsTheme(this.themeName.trim());
      this.args.closeModal();
    } catch {
      // error already shown by popupAjaxError in the service
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "styleguide.theme_builder.save_dialog.title"}}
      @closeModal={{@closeModal}}
      class="theme-builder-save-modal"
    >
      <:body>
        <label>
          {{i18n "styleguide.theme_builder.save_dialog.name_label"}}
        </label>
        <input
          type="text"
          value={{this.themeName}}
          placeholder={{i18n
            "styleguide.theme_builder.save_dialog.name_placeholder"
          }}
          class="theme-builder-save-modal__input"
          {{on "input" this.updateName}}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="styleguide.theme_builder.save_dialog.save"
          class="btn-primary"
          @disabled={{this.isDisabled}}
          @isLoading={{this.isSaving}}
        />
        <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
      </:footer>
    </DModal>
  </template>
}
