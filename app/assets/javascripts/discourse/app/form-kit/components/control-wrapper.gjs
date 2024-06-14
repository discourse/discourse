import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import FKLabel from "discourse/form-kit/components/label";
import FKMeta from "discourse/form-kit/components/meta";
import FormText from "discourse/form-kit/components/text";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

export default class FKControlWrapper extends Component {
  get controlType() {
    switch (this.args.component.name) {
      case "FKControlToggle":
        return "-toggle";
      case "FKControlInput":
        return "-input";
      case "FKControlComposer":
        return "-composer";
      case "FKControlText":
        return "-text";
      case "FKControlQuestion":
        return "-question";
      case "FKControlCode":
        return "-code";
      case "FKControlSelect":
        return "-select";
      case "FKControlIcon":
        return "-icon";
      case "FKControlImage":
        return "-image";
      case "FKControlMenu":
        return "-menu";
      case "FKControlRadioGroup":
        return "-radio-group";
    }
  }

  <template>
    <div
      class={{concatClass
        "form-kit__field"
        (concat "form-kit__field" this.controlType)
        (if @hasErrors "has-errors")
      }}
      data-disabled={{@field.disabled}}
      data-name={{@field.name}}
      data-value={{@value}}
    >
      {{#if @title}}
        <FKLabel class="form-kit__field-title" @fieldId={{@field.id}}>
          {{@title}}

          {{#unless @field.required}}
            <span class="form-kit__field-optional">({{i18n
                "form_kit.optional"
              }})</span>
          {{/unless}}
        </FKLabel>
      {{/if}}

      {{#if @subtitle}}
        <FormText class="form-kit__field-subtitle">{{@subtitle}}</FormText>
      {{/if}}

      <div class={{concatClass "form-kit__field-content" @format}}>
        <@component
          @field={{@field}}
          @value={{@value}}
          @type={{@type}}
          @lang={{@lang}}
          @positiveLabel={{@positiveLabel}}
          @negativeLabel={{@negativeLabel}}
          @selection={{@selection}}
          @setValue={{@setValue}}
          @set={{@set}}
          @height={{@height}}
          id={{@field.id}}
          name={{@field.name}}
          aria-invalid={{if @hasErrors "true"}}
          aria-describedby={{if @hasErrors @field.errorId}}
          ...attributes
          as |components|
        >
          {{yield components}}
        </@component>

        <FKMeta
          @hasErrors={{@hasErrors}}
          @description={{@description}}
          @value={{@value}}
          @field={{@field}}
          @errors={{@errors}}
        />
      </div>
    </div>
  </template>
}
