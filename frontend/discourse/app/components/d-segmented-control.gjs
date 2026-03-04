import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import uniqueId from "discourse/helpers/unique-id";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class DSegmentedControl extends Component {
  get legend() {
    if (this.args.label) {
      return i18n(this.args.label);
    }
    return this.args.translatedLabel;
  }

  @action
  handleChange(value) {
    this.args.onSelect?.(value);
  }

  <template>
    {{#let (uniqueId) as |groupName|}}
      <fieldset class="d-segmented-control" ...attributes>
        {{#if this.legend}}
          <legend class="d-segmented-control__legend">
            {{this.legend}}
          </legend>
        {{/if}}

        {{#each @items as |item|}}
          {{#let (uniqueId) as |id|}}
            <input
              type="radio"
              id={{id}}
              name={{groupName}}
              value={{item.value}}
              checked={{eq @value item.value}}
              class="d-segmented-control__input"
              {{on "change" (fn this.handleChange item.value)}}
            />
            <label
              for={{id}}
              class="d-segmented-control__label
                {{if
                  (eq @value item.value)
                  'd-segmented-control__label --selected'
                }}"
            >
              {{item.label}}
            </label>
          {{/let}}
        {{/each}}

      </fieldset>
    {{/let}}
  </template>
}
