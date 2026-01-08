import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

/**
 * The default content component for a toast.
 * Displays an icon, title, message, and action/cancel buttons.
 *
 * @component d-default-toast
 * @param {DToastInstance} toast - The toast instance
 * @param {Function} close - Callback to close the toast
 * @param {boolean} isFront - Whether this toast is at the front
 * @param {SafeString} progressBarStyle - The style to apply to the progress bar
 * @param {Function} onProgressComplete - Callback when the progress animation completes
 */
export default class DDefaultToast extends Component {
  /**
   * Returns the primary action for the toast, handling both new and legacy formats.
   *
   * @returns {Object|null}
   */
  get primaryAction() {
    const data = this.args.toast.options.data;

    if (data.action) {
      return data.action;
    }

    const firstLegacyAction = data.actions?.[0];
    if (firstLegacyAction) {
      return {
        label: firstLegacyAction.label,
        onClick: () =>
          firstLegacyAction.action({
            data,
            close: this.args.close,
          }),
      };
    }

    return null;
  }

  @action
  handlePrimaryAction() {
    this.args.close();
    this.primaryAction?.onClick?.();
  }

  @action
  handleCancelAction() {
    this.args.close();
    this.args.toast.options.data.cancel?.onClick?.();
  }

  <template>
    <div
      class={{concatClass
        "fk-d-default-toast"
        (if @toast.options.data.theme (concat "fk-d-default-toast--" @toast.options.data.theme))
        (if @toast.options.showProgressBar "fk-d-default-toast--has-progress")
      }}
      ...attributes
    >
      {{#if @toast.options.showProgressBar}}
        <div class="fk-d-default-toast__progress-wrapper">
          <div
            class="fk-d-default-toast__progress-bar"
            style={{@progressBarStyle}}
            {{on "animationend" @onProgressComplete}}
          ></div>
        </div>
      {{/if}}

      {{#if @isFront}}
        <button
          type="button"
          {{on "click" @close}}
          class="fk-d-default-toast__close-btn"
          aria-label={{i18n "close"}}
        >
          {{icon "xmark"}}
        </button>
      {{/if}}

      {{#if @toast.options.data.icon}}
        <div class="fk-d-default-toast__icon">
          {{icon @toast.options.data.icon}}
        </div>
      {{/if}}

      <div class="fk-d-default-toast__content">
        {{#if @toast.options.data.title}}
          <div class="fk-d-default-toast__title">
            {{@toast.options.data.title}}
          </div>
        {{/if}}

        {{#if (or @toast.options.data.message @toast.options.data.description)}}
          <div class="fk-d-default-toast__description">
            {{#if @toast.options.data.isHtmlMessage}}
              {{htmlSafe (or @toast.options.data.message @toast.options.data.description)}}
            {{else}}
              {{or @toast.options.data.message @toast.options.data.description}}
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if this.primaryAction}}
        <DButton
          class="fk-d-default-toast__action-btn btn-default btn-primary btn-small"
          {{on "click" this.handlePrimaryAction}}
        >
          {{this.primaryAction.label}}
        </DButton>
      {{/if}}

      {{#if @toast.options.data.cancel}}
        <DButton
          class="fk-d-default-toast__cancel-btn btn-default btn-small"
          {{on "click" this.handleCancelAction}}
        >
          {{or @toast.options.data.cancel.label (i18n "cancel")}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
