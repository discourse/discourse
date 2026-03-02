import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DDefaultToast extends Component {
  get data() {
    return this.args.toast.options.data ?? {};
  }

  get primaryAction() {
    const data = this.data;

    if (!Object.keys(data).length) {
      return null;
    }

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
    this.data.cancel?.onClick?.();
  }

  <template>
    <div
      class={{dConcatClass
        "fk-d-default-toast"
        (if this.data.theme (concat "fk-d-default-toast--" this.data.theme))
        (if @toast.options.showProgressBar "fk-d-default-toast--has-progress")
      }}
      ...attributes
    >
      {{#if @toast.options.autoClose}}
        {{#if @toast.options.showProgressBar}}
          <div class="fk-d-default-toast__progress-wrapper">
            <div
              class="fk-d-default-toast__progress-bar"
              style={{@progressBarStyle}}
              {{on "animationend" @onProgressComplete}}
            ></div>
          </div>
        {{else}}
          <div
            class="fk-d-default-toast__progress-bar --hidden"
            style={{@progressBarStyle}}
            {{on "animationend" @onProgressComplete}}
          ></div>
        {{/if}}
      {{/if}}

      {{#if @isFront}}
        <DButton
          class="fk-d-default-toast__close-btn"
          @icon="xmark"
          @action={{@close}}
          @translatedAriaLabel={{i18n "close"}}
        />
      {{/if}}

      {{#if this.data.icon}}
        <div class="fk-d-default-toast__icon">
          {{dIcon this.data.icon}}
        </div>
      {{/if}}

      <div class="fk-d-default-toast__content">
        {{#if this.data.title}}
          <div class="fk-d-default-toast__title">
            {{this.data.title}}
          </div>
        {{/if}}

        {{#if (or this.data.message this.data.description)}}
          <div class="fk-d-default-toast__description">
            {{#if this.data.isHtmlMessage}}
              {{trustHTML (or this.data.message this.data.description)}}
            {{else}}
              {{or this.data.message this.data.description}}
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if this.primaryAction}}
        <DButton
          class="fk-d-default-toast__action-btn btn-primary btn-small"
          @action={{this.handlePrimaryAction}}
          @translatedLabel={{this.primaryAction.label}}
        />
      {{/if}}

      {{#if this.data.cancel}}
        <DButton
          class="fk-d-default-toast__cancel-btn btn-small"
          @action={{this.handleCancelAction}}
          @translatedLabel={{or this.data.cancel.label (i18n "cancel")}}
        />
      {{/if}}
    </div>
  </template>
}
