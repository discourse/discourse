import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class DToggleSwitch extends Component {
  get computedLabel() {
    if (this.args.label) {
      return I18n.t(this.args.label);
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
            {{icon "check"}}
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
