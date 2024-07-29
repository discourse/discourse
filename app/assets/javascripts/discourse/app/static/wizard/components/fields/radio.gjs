import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse-common/helpers/d-icon";

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
    this.field.value = input.target.value;
    this._resetSelected();
    this._setSelected();
  }

  _resetSelected() {
    for (let choice of this.field.choices) {
      set(choice, "selected", false);
    }
  }

  _setSelected() {
    for (let choice of this.field.choices) {
      if (this.field.value === choice.id) {
        set(choice, "selected", true);
      }
    }
  }

  <template>
    <div class="wizard-container__radio-choices">
      {{#each @field.choices as |c|}}
        <div
          class="wizard-container__radio-choice {{if c.selected 'selected'}}"
        >
          <label class="wizard-container__label">
            <PluginOutlet
              @name="wizard-radio"
              @outletArgs={{hash disabled=c.disabled}}
            >
              <Input
                @type="radio"
                @value={{c.id}}
                class="wizard-container__radio"
                disabled={{c.disabled}}
                selected={{c.selected}}
                {{on "click" this.selectionChanged}}
              />
              <span class="wizard-container__radio-label">
                {{#if c.icon}}
                  {{icon c.icon}}
                {{/if}}
                <span>{{c.label}}</span>
              </span>
            </PluginOutlet>

            <PluginOutlet
              @name="below-wizard-radio"
              @outletArgs={{hash disabled=c.disabled}}
            />
          </label>
        </div>
      {{/each}}
    </div>
  </template>
}
