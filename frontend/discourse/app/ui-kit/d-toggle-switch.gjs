import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DToggleSwitch extends Component {
  get computedLabel() {
    if (this.args.label) {
      return i18n(this.args.label);
    }
    return this.args.translatedLabel;
  }

  <template>
    <div class="d-toggle-switch">
      <label class="d-toggle-switch__label">
        <button
          class="d-toggle-switch__checkbox"
          type="button"
          role="switch"
          aria-checked={{if @state "true" "false"}}
          ...attributes
        ></button>

        <span class="d-toggle-switch__checkbox-slider">
          {{#if @state}}
            {{dIcon "check"}}
          {{/if}}
        </span>
      </label>

      {{#if this.computedLabel}}
        <span class="d-toggle-switch__checkbox-label">
          {{this.computedLabel}}
        </span>
      {{/if}}
    </div>
  </template>
}
