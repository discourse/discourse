import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import { concat, fn, hash } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import or from "truth-helpers/helpers/or";

const DDefaultToast = <template>
  <div
    class={{concatClass
      "fk-d-default-toast"
      (concat "-" (or @data.theme "default"))
    }}
    ...attributes
  >
    {{#if @data.icon}}
      <div class="fk-d-default-toast__icon-container">
        {{icon @data.icon}}
      </div>
    {{/if}}
    <div class="fk-d-default-toast__main-container">
      <div class="fk-d-default-toast__texts">
        {{#if @data.title}}
          <div class="fk-d-default-toast__title">
            {{@data.title}}
          </div>
        {{/if}}
        {{#if @data.message}}
          <div class="fk-d-default-toast__message">
            {{@data.message}}
          </div>
        {{/if}}
      </div>

      {{#if @data.actions}}
        <div class="fk-d-default-toast__actions">
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
    </div>
    <div class="fk-d-default-toast__close-container">
      <DButton class="btn-flat" @icon="times" @action={{@close}} />
    </div>
  </div>
</template>;

export default DDefaultToast;
