import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";

export default class Radio extends Component {
  constructor() {
    super(...arguments);

    this._setSelected();
  }

  get field() {
    return this.args.field;
  }

  @action
  selectionChanged(input) {
    this.field.value = input;
    this._setSelected();
  }

  _setSelected() {
    for (let choice of this.field.choices) {
      set(choice, "selected", this.field.value === choice.id);
    }
  }

  <template>
    <div class="wizard-container__radio-choices">
      {{#each @field.choices as |choice|}}
        <div
          class={{concatClass
            "wizard-container__radio-choice"
            (if choice.selected "--selected")
          }}
          data-choice-id={{choice.id}}
        >
          <label class="wizard-container__label">
            <PluginOutlet
              @name="wizard-radio"
              @outletArgs={{hash disabled=choice.disabled}}
            >
              <input
                type="radio"
                value={{choice.id}}
                class="wizard-container__radio"
                disabled={{choice.disabled}}
                checked={{choice.selected}}
                {{on "change" (withEventValue this.selectionChanged)}}
              />
              <span class="wizard-container__radio-label">
                {{#if choice.icon}}
                  {{icon choice.icon}}
                {{/if}}
                <span>{{choice.label}}</span>
              </span>
            </PluginOutlet>

            <PluginOutlet
              @name="below-wizard-radio"
              @outletArgs={{hash disabled=choice.disabled}}
            />
          </label>
        </div>
      {{/each}}
    </div>
  </template>
}
