import Component from "@glimmer/component";
import { action } from "@ember/object";
import FormControlInput from "form-kit/components/form/control/input";

export default class FormFieldsInput extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
  }

  <template>
    <div class="d-form-control">
      <label class="d-form-checkbox-label" for={{@name}}>
        {{@label}}
      </label>

      <FormControlInput
        @value={{@value}}
        @id={{@fieldId}}
        @errorId={{@fieldErrorId}}
        @name={{@name}}
        @setValue={{@setValue}}
        @registerFieldWithType={{@registerFieldWithType}}
        ...attributes
      />
    </div>
  </template>
}
