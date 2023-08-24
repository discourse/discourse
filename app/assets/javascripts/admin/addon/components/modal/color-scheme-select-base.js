import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class ColorSchemeSelectBase extends Component {
  @tracked
  selectedBaseThemeId = this.args.model.baseColorSchemes?.[0]?.base_scheme_id;

  @action
  selectBase() {
    this.args.model.newColorSchemeWithBase(this.selectedBaseThemeId);
    this.args.closeModal();
  }
}
