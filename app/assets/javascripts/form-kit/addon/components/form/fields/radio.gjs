import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class FormFieldsCheckbox extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
  }

  <template>
    <div class="d-form-radio">
      <input
        checked={{@value}}
        id={{@fieldId}}
        name={{@name}}
        aria-invalid={{if @invalid "true"}}
        type="radio"
        class="d-form-radio__input"
        {{on "click" this.handleInput}}
        ...attributes
      />

      <label class="d-form-radio__label" for={{@name}}>
        {{@label}}
      </label>
    </div>
  </template>
}
