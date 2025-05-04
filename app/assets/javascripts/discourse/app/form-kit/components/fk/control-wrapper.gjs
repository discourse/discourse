import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKMeta from "discourse/form-kit/components/fk/meta";
import FKOptional from "discourse/form-kit/components/fk/optional";
import FKText from "discourse/form-kit/components/fk/text";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";
import concatClass from "discourse/helpers/concat-class";

export default class FKControlWrapper extends Component {
  @tracked controlWidth = "auto";

  constructor() {
    super(...arguments);

    this.args.field.type = this.args.component.controlType;
  }

  get controlType() {
    if (this.args.field.type === "input") {
      return this.args.field.type + "-" + (this.args.type || "text");
    }

    return this.args.field.type;
  }

  get error() {
    return (this.args.errors ?? {})[this.args.field.name];
  }

  get titleFormat() {
    return this.args.field.titleFormat || this.args.field.format;
  }

  get descriptionFormat() {
    return this.args.field.descriptionFormat || this.args.field.format;
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
      {{didInsert (fn @registerField @field.name @field)}}
      {{willDestroy (fn @unregisterField @field.name)}}
    >
      {{#unless (eq @field.type "checkbox")}}
        {{#if @field.showTitle}}
          <FKLabel
            class={{concatClass
              "form-kit__container-title"
              (if this.titleFormat (concat "--" this.titleFormat))
            }}
            @fieldId={{@field.id}}
          >
            <span>{{@field.title}}</span>

            <FKOptional @field={{@field}} />
            <FKTooltip @field={{@field}} />
          </FKLabel>
        {{/if}}

        {{#if @field.description}}
          <FKText
            class={{concatClass
              "form-kit__container-description"
              (if this.descriptionFormat (concat "--" this.descriptionFormat))
            }}
          >{{@field.description}}</FKText>
        {{/if}}
      {{/unless}}

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
          @preview={{@preview}}
          @includeTime={{@includeTime}}
          @expandedDatePickerOnDesktop={{@expandedDatePickerOnDesktop}}
          @selection={{@selection}}
          @includeNone={{@includeNone}}
          @onControlWidthChange={{fn (mut this.controlWidth)}}
          id={{@field.id}}
          name={{@field.name}}
          aria-invalid={{if this.error "true"}}
          aria-describedby={{if this.error @field.errorId}}
          ...attributes
          as |components|
        >
          {{yield components}}
        </@component>

        {{#if @field.helpText}}
          <FKText
            class="form-kit__container-help-text"
          >{{@field.helpText}}</FKText>
        {{/if}}

        <FKMeta
          @field={{@field}}
          @error={{this.error}}
          @controlWidth={{this.controlWidth}}
        />
      </div>
    </div>
  </template>
}
