import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "form-kit/components/label";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";

export default class FkControlQuestion extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.value);
  }

  <template>
    <div class="d-form__inline-radio">
      {{#let (uniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="d-form__control-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{true}}
            checked={{eq @value true}}
            class="d-form__control-radio"
            disabled={{@disabled}}
            ...attributes
            id={{uuid}}
            {{on "change" this.handleInput}}
          />

          {{#if @positiveLabel}}
            {{@positiveLabel}}
          {{else}}
            Yes
          {{/if}}
        </FKLabel>
      {{/let}}

      {{#let (uniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="d-form__control-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{false}}
            checked={{eq @value false}}
            class="d-form__control-radio"
            disabled={{@disabled}}
            ...attributes
            id={{uuid}}
            {{on "change" this.handleInput}}
          />

          {{#if @negativeLabel}}
            {{@negativeLabel}}
          {{else}}
            No
          {{/if}}
        </FKLabel>
      {{/let}}
    </div>
  </template>
}
