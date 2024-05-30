import Component from "@glimmer/component";
import { action } from "@ember/object";
import FormControlInput from "form-kit/components/form/control/input";
import FormErrors from "form-kit/components/form/errors";
import FormText from "form-kit/components/form/text";

export default class FormFieldsInput extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
  }

  get showErrors() {
    return this.args.showErrors ?? true;
  }

  <template>
    {{#if @label}}
      <label class="d-form-input-label" for={{@name}}>
        {{@label}}

        {{#unless @required}}
          <span class="d-form-field__optional">(Optional)</span>
        {{/unless}}
      </label>
    {{/if}}

    {{#if @help}}
      <FormText>{{@help}}</FormText>
    {{/if}}

    <FormControlInput
      @value={{@value}}
      @id={{@fieldId}}
      @errorId={{@fieldErrorId}}
      @name={{@name}}
      @setValue={{@setValue}}
      disabled={{@disabled}}
      ...attributes
    />

    {{log "showErrors" @showErrors}}

    {{#if this.showErrors}}
      <FormErrors @id={{@errorId}} @errors={{@errors}} />
    {{/if}}
  </template>
}
