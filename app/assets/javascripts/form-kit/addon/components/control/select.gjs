import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";
import FkControlSelectOption from "./select/option";

export default class FkControlSelect extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.value);
  }

  <template>
    {{#if @label}}
      <label class="d-form-content-label" for={{@name}}>
        {{@label}}

        {{#unless @required}}
          <span class="d-form-field__optional">(Optional)</span>
        {{/unless}}
      </label>
    {{/if}}

    {{#if @help}}
      <FormText>{{@help}}</FormText>
    {{/if}}

    <select
      name={{@name}}
      value={{@value}}
      id={{@fieldId}}
      aria-invalid={{if @invalid "true"}}
      aria-describedby={{if @invalid @errorId}}
      ...attributes
      class="d-form-select"
      {{on "input" this.handleInput}}
    >
      {{yield (hash Option=(component FkControlSelectOption selected=@value))}}
    </select>

    <FormMeta
      @description={{@description}}
      @disabled={{@disabled}}
      @value={{@value}}
      @maxLength={{@maxLength}}
      @errorId={{@errorId}}
      @errors={{@errors}}
    />
  </template>
}
