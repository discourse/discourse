import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class ColorSchemeSelectBase extends Component {
  @tracked
  selectedBaseThemeId = this.args.model.baseColorSchemes?.[0]?.base_scheme_id;

  @action
  selectBase() {
    this.args.model.newColorSchemeWithBase(this.selectedBaseThemeId);
    this.args.closeModal();
  }
}

<DModal
  @title={{i18n "admin.customize.colors.select_base.title"}}
  @closeModal={{@closeModal}}
>
  <:body>
    {{i18n "admin.customize.colors.select_base.description"}}
    <ComboBox
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