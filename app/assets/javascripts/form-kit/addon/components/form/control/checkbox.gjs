import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class FormControlCheckbox extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
  }

  <template>
    <input
      ...attributes
      name={{@name}}
      type="checkbox"
      checked={{@value}}
      id={{@fieldId}}
      aria-invalid={{if @invalid "true"}}
      {{on "click" this.handleInput}}
    />
  </template>
}
