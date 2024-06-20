import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import FKLabel from "discourse/form-kit/components/label";
import FKMeta from "discourse/form-kit/components/meta";
import FormText from "discourse/form-kit/components/text";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

export default class FKControlWrapper extends Component {
  get controlType() {
    switch (this.args.component.name) {
      case "FKControlRadioGroup":
        return "radio-group";
      case "FKControlToggle":
        return "toggle";
      case "FKControlInput":
        return "input-" + (this.args.type || "text");
      case "FKControlComposer":
        return "composer";
      case "FKControlText":
        return "text";
      case "FKControlQuestion":
        return "question";
      case "FKControlCode":
        return "code";
      case "FKControlSelect":
        return "select";
      case "FKControlIcon":
        return "icon";
      case "FKControlImage":
        return "image";
      case "FKControlCheckbox":
        return "checkbox";
      case "FKControlMenu":
        return "menu";
    }
  }

  @action
  setFieldType() {
    this.args.field.type = this.controlType;
  }

  <template>
    <div
      class={{concatClass
        "form-kit__container"
        "form-kit__field"
        (concat "form-kit__field-" this.controlType)
        (if @field.hasErrors "has-errors")
      }}
      data-disabled={{@field.disabled}}
      data-name={{@field.name}}
      data-value={{@value}}
      data-control-type={{this.controlType}}
      {{didInsert this.setFieldType}}
    >
      {{#if @field.showTitle}}
        <FKLabel class="form-kit__container-title" @fieldId={{@field.id}}>
          {{@field.title}}

          {{#unless @field.required}}
            <span class="form-kit__container-optional">({{i18n
                "form_kit.optional"
              }})</span>
          {{/unless}}
        </FKLabel>
      {{/if}}

      {{#if @field.subtitle}}
        <FormText
          class="form-kit__container-subtitle"
        >{{@field.subtitle}}</FormText>
      {{/if}}

      <div class={{concatClass "form-kit__container-content" @format}}>
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
          @formElement={{@formElement}}
          id={{@field.id}}
          name={{@field.name}}
          aria-invalid={{if @field.hasErrors "true"}}
          aria-describedby={{if @field.hasErrors @field.errorId}}
          ...attributes
          as |components|
        >
          {{yield components}}
        </@component>

        <FKMeta
          @description={{@description}}
          @value={{@value}}
          @field={{@field}}
        />
      </div>
    </div>
  </template>
}
