import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import uniqueId from "discourse/helpers/unique-id";
import { i18n } from "discourse-i18n";

export default class FKControlQuestion extends Component {
  static controlType = "question";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value === "true");
  }

  <template>
    <div class="form-kit__inline-radio">
      {{#let (uniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label --yes">
          <input
            name={{@field.name}}
            type="radio"
            value="true"
            checked={{eq @value true}}
            class="form-kit__control-radio"
            disabled={{@disabled}}
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

      {{#let (uniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label --no">
          <input
            name={{@field.name}}
            type="radio"
            value="false"
            checked={{eq @value false}}
            class="form-kit__control-radio"
            disabled={{@disabled}}
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
