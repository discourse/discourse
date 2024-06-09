import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import FKMeta from "form-kit/components/meta";
import FormText from "form-kit/components/text";

export default class FormControlWrapper extends Component {
  get controlType() {
    switch (this.args.component.name) {
      case "FkControlInput":
        return "-input";
      case "FkControlText":
        return "-text";
      case "FkControlYesNo":
        return "-yes-no";
      case "FkControlSelect":
        return "-select";
      case "FkControlIconSelector":
        return "-icon";
      case "FkControlImage":
        return "-image";
      case "FkControlMenu":
        return "-menu";
      case "FkControlRadioGroup":
        return "-radio-group";
    }
  }

  <template>
    <div class={{concat "d-form__field" this.controlType}}>
      {{#if @title}}
        <label class="d-form__field__title" for={{@fieldId}}>
          {{@title}}

          {{#unless @field.required}}
            <span class="d-form__field__optional">(Optional)</span>
          {{/unless}}
        </label>
      {{/if}}

      {{#if @subtitle}}
        <FormText class="d-form__field__subtitle">{{@subtitle}}</FormText>
      {{/if}}

      <@component
        @value={{@value}}
        @type={{@type}}
        @positiveLabel={{@positiveLabel}}
        @negativeLabel={{@negativeLabel}}
        @setValue={{@setValue}}
        @disabled={{@field.disabled}}
        id={{@fieldId}}
        name={{@name}}
        aria-invalid={{if @invalid "true"}}
        aria-describedby={{if @invalid @errorId}}
        ...attributes
        as |components|
      >
        {{yield components}}
      </@component>

      <FKMeta
        @description={{@description}}
        @value={{@value}}
        @field={{@field}}
        @errorId={{@errorId}}
        @errors={{@errors}}
      />
    </div>
  </template>
}
