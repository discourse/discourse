import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKLabel from "discourse/form-kit/components/fk/label";
import { eq } from "discourse/truth-helpers";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import { i18n } from "discourse-i18n";

export default class FKControlQuestion extends FKBaseControl {
  static controlType = "question";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value === "true");
  }

  <template>
    <div class="form-kit__inline-radio">
      {{#let (dUniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label --yes">
          <input
            name={{@field.name}}
            type="radio"
            value="true"
            checked={{eq @field.value true}}
            class="form-kit__control-radio"
            disabled={{@field.disabled}}
            aria-describedby={{if @field.error @field.errorId}}
            ...attributes
            id={{uuid}}
            {{on "change" this.handleInput}}
          />

          {{#if @yesLabel}}
            {{@yesLabel}}
          {{else}}
            {{i18n "yes_value"}}
          {{/if}}
        </FKLabel>
      {{/let}}

      {{#let (dUniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label --no">
          <input
            name={{@field.name}}
            type="radio"
            value="false"
            checked={{eq @field.value false}}
            class="form-kit__control-radio"
            disabled={{@field.disabled}}
            aria-describedby={{if @field.error @field.errorId}}
            ...attributes
            id={{uuid}}
            {{on "change" this.handleInput}}
          />

          {{#if @noLabel}}
            {{@noLabel}}
          {{else}}
            {{i18n "no_value"}}
          {{/if}}
        </FKLabel>
      {{/let}}
    </div>
  </template>
}
