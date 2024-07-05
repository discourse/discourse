import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKMeta from "discourse/form-kit/components/fk/meta";
import FormText from "discourse/form-kit/components/fk/text";
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
      case "FKControlTextarea":
        return "textarea";
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
      default:
        return "custom";
    }
  }

  @action
  setFieldType() {
    this.args.field.type = this.controlType;
  }

  get props() {
    const props = {};

    switch (this.args.component.name) {
      case "FKControlInput":
        props.type = this.args.type;
        break;
      case "FKControlQuestion":
        props.yesLabel = this.args.yesLabel;
        props.noLabel = this.args.noLabel;
        break;
      case "FKControlCode":
        props.lang = this.args.lang;
        props.height = this.args.height;
        break;
      case "FKControlText":
        props.height = this.args.height;
        break;
      case "FKControlComposer":
        props.height = this.args.height;
        break;
      case "FKControlMenu":
        props.selection = this.args.selection;
        break;
    }

    return new TrackedObject(props);
  }

  get error() {
    return (this.args.errors ?? {})[this.args.field.name];
  }

  get hasErrors() {
    return this.errors?.length > 0;
  }

  normalizeName(name) {
    return name.replace(/\./g, "-");
  }

  <template>
    <div
      id={{concat "control-" (this.normalizeName @field.name)}}
      class={{concatClass
        "form-kit__container"
        "form-kit__field"
        (concat "form-kit__field-" this.controlType)
        (if this.hasErrors "has-errors")
      }}
      data-disabled={{@field.disabled}}
      data-name={{@field.name}}
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

      <div
        class={{concatClass
          "form-kit__container-content"
          (if @format (concat "--" @format))
        }}
      >
        <@component
          @field={{@field}}
          @value={{@value}}
          @props={{this.props}}
          id={{@field.id}}
          name={{@field.name}}
          aria-invalid={{if this.hasErrors "true"}}
          aria-describedby={{if this.hasErrors @field.errorId}}
          ...attributes
          as |components|
        >
          {{yield components}}
        </@component>

        <FKMeta
          @description={{@description}}
          @value={{@value}}
          @field={{@field}}
          @error={{this.error}}
        />
      </div>
    </div>
  </template>
}
