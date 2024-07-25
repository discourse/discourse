import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class DToggleSwitch extends Component {
  <template>
    <div class="d-toggle-switch">
      <label class="d-toggle-switch__label">
        {{! template-lint-disable no-redundant-role }}
        <button
          class="d-toggle-switch__checkbox"
          type="button"
          role="switch"
          aria-checked={{this.checked}}
          ...attributes
        ></button>
        {{! template-lint-enable no-redundant-role }}

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

  get computedLabel() {
    if (this.args.label) {
      return I18n.t(this.args.label);
    }
    return this.args.translatedLabel;
  }

  get checked() {
    return this.args.state ? "true" : "false";
  }
}
