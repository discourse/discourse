import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class FormFieldsCheckbox extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
  }

  <template>
    <div class="d-form-checkbox">
      <input
        checked={{@value}}
        id={{@fieldId}}
        name={{@name}}
        aria-invalid={{if @invalid "true"}}
        type="checkbox"
        class="d-form-checkbox-input"
        {{on "click" this.handleInput}}
        ...attributes
      />

      <label class="d-form-checkbox-label" for={{@name}}>
        {{@label}}
      </label>
    </div>
  </template>
}
