import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class ColorSchemeSelectBase extends Component {
  @tracked
  selectedBaseThemeId = this.args.model.baseColorSchemes?.[0]?.base_scheme_id;

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
        <ComboBox
          class="select-base-palette"
          @content={{@model.baseColorSchemes}}
          @value={{this.selectedBaseThemeId}}
          @onChange={{fn (mut this.selectedBaseThemeId)}}
          @valueProperty="base_scheme_id"
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
