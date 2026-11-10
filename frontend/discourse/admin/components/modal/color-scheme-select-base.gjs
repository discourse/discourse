import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import ColorPalettePicker from "discourse/select-kit/components/color-palette-picker";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class ColorSchemeSelectBase extends Component {
  @tracked selectedBaseThemeId = this.args.model.colorSchemes?.[0]?.id;

  @action
  selectBase() {
    this.args.model.newColorSchemeWithBase(this.selectedBaseThemeId);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="create-color-palette"
      @closeModal={{@closeModal}}
      @title={{i18n "admin.customize.colors.select_base.title"}}
    >
      <:body>
        {{i18n "admin.customize.colors.select_base.description"}}
        <ColorPalettePicker
          class="select-base-palette"
          @content={{@model.colorSchemes}}
          @onChange={{fn (mut this.selectedBaseThemeId)}}
          @value={{this.selectedBaseThemeId}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.selectBase}}
          @icon="plus"
          @label="admin.customize.new"
        />
      </:footer>
    </DModal>
  </template>
}
