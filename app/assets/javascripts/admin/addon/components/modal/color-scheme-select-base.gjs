import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ColorPalettePicker from "select-kit/components/color-palette-picker";

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
      @title={{i18n "admin.customize.colors.select_base.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{i18n "admin.customize.colors.select_base.description"}}
        <ColorPalettePicker
          @content={{@model.colorSchemes}}
          @value={{this.selectedBaseThemeId}}
          @onChange={{fn (mut this.selectedBaseThemeId)}}
          class="select-base-palette"
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
