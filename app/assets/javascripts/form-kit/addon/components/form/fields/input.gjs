import Component from "@glimmer/component";
import { action } from "@ember/object";
import FormControlInput from "form-kit/components/form/control/input";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";

export default class FormFieldsInput extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.checked);
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

    <FormMeta
      @description={{@description}}
      @disabled={{@disabled}}
      @value={{@value}}
      @maxLength={{@maxLength}}
      @errorId={{@fieldErrorId}}
      @errors={{@errors}}
    />
  </template>
}
