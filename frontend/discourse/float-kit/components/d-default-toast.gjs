import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class DDefaultToast extends Component {
  @action
  handleAction() {
    this.args.sheet.close();
    this.args.data.action.onClick();
  }

  @action
  handleCancel() {
    this.args.sheet.close();
    this.args.data.cancel.onClick();
  }

  <template>
    <div
      class={{concatClass
        "fk-d-default-toast"
        (concat "-" (or @data.theme "default"))
        (if @showProgressBar "-has-progress")
      }}
      ...attributes
    >
      {{#if @showProgressBar}}
        <div class="fk-d-default-toast__progress-wrapper">
          <div
            class="fk-d-default-toast__progress-bar"
            {{didInsert @registerProgressBar}}
          ></div>
        </div>
      {{/if}}

      {{#if @isFront}}
        <button
          {{on "click" @sheet.close}}
          class="fk-d-default-toast__close-btn"
          aria-label="Close"
        >
          {{icon "xmark"}}
        </button>
      {{/if}}

      {{#if @data.icon}}
        <div class="fk-d-default-toast__icon">
          {{icon @data.icon}}
        </div>
      {{/if}}

      <div class="fk-d-default-toast__content">
        {{#if @data.title}}
          <div class="fk-d-default-toast__title">
            {{@data.title}}
          </div>
        {{/if}}
        {{#if (or @data.message @data.description)}}
          <div class="fk-d-default-toast__description">
            {{#if @data.isHtmlMessage}}
              {{htmlSafe (or @data.message @data.description)}}
            {{else}}
              {{or @data.message @data.description}}
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{! Legacy actions array support }}
      {{#if @data.actions}}
        <div class="fk-d-default-toast__actions-legacy">
          {{#each @data.actions as |toastAction|}}
            {{#if toastAction.action}}
              <DButton
                @icon={{toastAction.icon}}
                @translatedLabel={{toastAction.label}}
                @action={{fn toastAction.action (hash data=@data close=@close)}}
                class={{toastAction.class}}
                tabindex="0"
              />
            {{/if}}
          {{/each}}
        </div>
      {{/if}}

      {{#if @data.action}}
        <DButton
          class="fk-d-default-toast__action-btn btn-default btn-primary btn-small"
          {{on "click" this.handleAction}}
        >
          {{@data.action.label}}
        </DButton>
      {{/if}}

      {{#if @data.cancel}}
        <DButton
          class="fk-d-default-toast__cancel-btn btn-default btn-small"
          {{on "click" this.handleCancel}}
        >
          {{or @data.cancel.label (i18n "cancel")}}
        </DButton>
      {{/if}}
    </div>
  </template>
}
