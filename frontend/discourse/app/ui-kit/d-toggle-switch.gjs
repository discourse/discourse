// @ts-check
import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * A binary on/off toggle styled as a sliding switch. The component is a
 * presentation wrapper: it renders the visual state from `@state` and
 * surfaces the inner `<button role="switch">` via `...attributes` so the
 * parent can attach its own click handler. Use `DToggleSwitch` for binary
 * settings (notification on/off, feature flags); for any other input shape
 * reach for the matching FormKit field instead.
 *
 * @example
 * <DToggleSwitch
 *   @state={{this.notifications}}
 *   @label="user.notifications"
 *   {{on "click" this.toggleNotifications}}
 * />
 */

/**
 * @typedef DToggleSwitchSignature
 *
 * @property {object} Args
 *
 * @property {boolean} [Args.state] Current state of the switch. Renders `aria-checked="true"` when truthy, `"false"` otherwise. The component does not own the state — the parent updates the value in its own click handler.
 * @property {string} [Args.label] Translatable i18n key for the visible label rendered after the switch. Mutually exclusive with `translatedLabel`.
 * @property {string} [Args.translatedLabel] Pre-translated label. Use when the label is computed at runtime and already localized.
 *
 * @property {HTMLButtonElement} Element The inner `<button role="switch">` element. Click handlers and other event listeners passed via `...attributes` are attached here, not to the outer `<div>`.
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Not used.
 */

/** @extends {Component<DToggleSwitchSignature>} */
export default class DToggleSwitch extends Component {
  constructor(owner, args) {
    super(owner, args);

    assert(
      "[d-toggle-switch] pass either @label or @translatedLabel, not both",
      !(this.args.label && this.args.translatedLabel)
    );
  }

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
