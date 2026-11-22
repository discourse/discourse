import Component from "@glimmer/component";
import { guidFor } from "@ember/object/internals";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface DToggleSwitchSignature {
  Args: {
    /** Whether the switch is on. */
    state?: boolean;

    /** The translation key of the visible label. It takes precedence over `@translatedLabel`. */
    label?: string;

    /** The visible label, already translated. */
    translatedLabel?: string;
  };

  /** The switch button, so attributes such as `disabled` reach it. */
  Element: HTMLButtonElement;
}

export default class DToggleSwitch extends Component<DToggleSwitchSignature> {
  labelId = `${guidFor(this)}-label`;

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
          aria-checked={{if @state "true" "false"}}
          aria-labelledby={{if this.computedLabel this.labelId}}
          class="d-toggle-switch__checkbox"
          role="switch"
          type="button"
          ...attributes
        ></button>

        <span class="d-toggle-switch__checkbox-slider">
          {{#if @state}}
            {{dIcon "check"}}
          {{/if}}
        </span>
      </label>

      {{#if this.computedLabel}}
        <span class="d-toggle-switch__checkbox-label" id={{this.labelId}}>
          {{this.computedLabel}}
        </span>
      {{/if}}
    </div>
  </template>
}
