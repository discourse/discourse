import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import DSheet from "./d-sheet";

const DDefaultToast = <template>
    <div
    class={{concatClass
      "fk-d-default-toast"
      (concat "-" (or @data.theme "default"))
    }}
    ...attributes
  >
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

    {{! Sonner-style cancel button }}
    {{#if @data.cancel}}
      <button
        type="button"
        class="fk-d-default-toast__cancel-btn"
        {{on "click" (fn @data.cancel.onClick (hash data=@data close=@close))}}
      >
        {{@data.cancel.label}}
      </button>
    {{/if}}

    {{! Sonner-style action button }}
    {{#if @data.action}}
      <button
        type="button"
        class="fk-d-default-toast__action-btn"
        {{on "click" (fn @data.action.onClick (hash data=@data close=@close))}}
      >
        {{@data.action.label}}
      </button>
    {{/if}}
  </div>
</template>;

export default DDefaultToast;
