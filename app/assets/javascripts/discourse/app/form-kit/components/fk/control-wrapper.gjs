import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKMeta from "discourse/form-kit/components/fk/meta";
import FKText from "discourse/form-kit/components/fk/text";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class FKControlWrapper extends Component {
  get controlType() {
    if (this.args.component.controlType === "input") {
      return this.args.component.controlType + "-" + (this.args.type || "text");
    }

    return this.args.component.controlType;
  }

  get error() {
    return (this.args.errors ?? {})[this.args.field.name];
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
        (if this.error "has-error")
        (if @field.disabled "is-disabled")
        (if (eq @field.format "full") "--full")
      }}
      data-disabled={{@field.disabled}}
      data-name={{@field.name}}
      data-control-type={{this.controlType}}
      {{willDestroy (fn @unregisterField @field.name)}}
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

      {{#if @field.description}}
        <FKText
          class="form-kit__container-description"
        >{{@field.description}}</FKText>
      {{/if}}

      <div
        class={{concatClass
          "form-kit__container-content"
          (if @field.format (concat "--" @field.format))
        }}
      >
        <@component
          @field={{@field}}
          @value={{@value}}
          @type={{@type}}
          @yesLabel={{@yesLabel}}
          @noLabel={{@noLabel}}
          @lang={{@lang}}
          @before={{@before}}
          @after={{@after}}
          @height={{@height}}
          @selection={{@selection}}
          id={{@field.id}}
          name={{@field.name}}
          aria-invalid={{if this.error "true"}}
          aria-describedby={{if this.error @field.errorId}}
          ...attributes
          as |components|
        >
          {{yield components}}
        </@component>

        <FKMeta @field={{@field}} @error={{this.error}} />
      </div>
    </div>
  </template>
}
