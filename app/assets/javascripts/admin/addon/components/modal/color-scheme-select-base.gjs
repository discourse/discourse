import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import ColorPaletteEditor from "admin/components/color-palette-editor";
import ComboBox from "select-kit/components/combo-box";

export default class ColorSchemeSelectBase extends Component {
  @tracked selectedBaseThemeId = this.args.model.colorSchemes?.[0]?.id;

  @action
  selectBase() {
    this.args.model.newColorSchemeWithBase(this.selectedBaseThemeId);
    this.args.closeModal();
  }

  get colors() {
    let colors = this.args.model.colorSchemes.find(
      (scheme) => scheme.id === -1
    ).colors;
    colors = colors.map((color) => {
      color.originals.hex = "";
      color.default_hex = "";
      color.hex = "";
      return color;
    });

    return colors;
  }

  @action
  onColorChange(color, value) {
    color.hex = value;
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
          @content={{@model.colorSchemes}}
          @value={{this.selectedBaseThemeId}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{fn (mut this.selectedBaseThemeId)}}
          @options={{hash none="admin.customize.colors.select_base.none"}}
        />
        {{#unless this.selectedBaseThemeId}}
          <p>
            <ColorPaletteEditor
              @colors={{this.colors}}
              @onColorChange={{this.onColorChange}}
            />
          </p>
        {{/unless}}
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
