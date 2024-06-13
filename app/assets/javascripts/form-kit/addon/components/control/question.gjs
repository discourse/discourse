import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "form-kit/components/label";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";

export default class FKControlQuestion extends Component {
  @action
  handleInput(event) {
    if (this.args.onSet) {
      this.args.onSet(event.target.value, { set: this.args.set });
    } else {
      this.args.setValue(event.target.value);
    }
  }

  @action
  handleDestroy() {
    if (this.args.onUnset) {
      this.args.onUnset({ set: this.args.set });
    } else {
      this.args.setValue(undefined);
    }
  }

  <template>
    <div class="form-kit__inline-radio">
      {{#let (uniqueId) as |uuid|}}
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{true}}
            checked={{eq @value true}}
            class="form-kit__control-radio"
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
        <FKLabel @fieldId={{uuid}} class="form-kit__control-radio__label">
          <input
            name={{@name}}
            type="radio"
            value={{false}}
            checked={{eq @value false}}
            class="form-kit__control-radio"
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
