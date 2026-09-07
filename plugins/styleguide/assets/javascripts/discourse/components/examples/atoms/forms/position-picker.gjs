import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DPositionPicker from "discourse/ui-kit/d-position-picker";

export default class PositionPickerExample extends Component {
  @tracked position = { x: 50, y: 50 };
  @tracked preview = null;

  @action
  cancel() {
    this.preview = null;
  }

  @action
  change(position) {
    this.position = position;
    this.preview = null;
  }

  @action
  updatePreview(position) {
    this.preview = position;
  }

  <template>
    <DPositionPicker
      @onCancel={{this.cancel}}
      @onChange={{this.change}}
      @onPreview={{this.updatePreview}}
      @value={{if this.preview this.preview this.position}}
    />
  </template>
}
