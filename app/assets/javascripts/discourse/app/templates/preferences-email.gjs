import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import InputTip from "discourse/components/input-tip";
import TextField from "discourse/components/text-field";
import bodyClass from "discourse/helpers/body-class";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>
  {{bodyClass "user-preferences-page"}}

  <section class="user-content user-preferences solo-preference">
    <form class="form-vertical">
      {{#if @controller.success}}
        <div class="alert alert-success">{{@controller.successMessage}}</div>
        <LinkTo @route="preferences.account" class="success-back">
          {{dIcon "arrow-left"}}
          {{iN "user.change_email.back_to_preferences"}}
        </LinkTo>
      {{else}}
        {{#if @controller.error}}
          <div class="alert alert-error">{{@controller.errorMessage}}</div>
        {{/if}}
        <div class="control-group">
          <label class="control-label">
            {{iN
              (if
                @controller.new "user.add_email.title" "user.change_email.title"
              )
            }}
          </label>
          <div class="controls">
            <TextField
              @value={{@controller.newEmail}}
              @id="change-email"
              @classNames="input-xxlarge"
              @autofocus="autofocus"
            />
            <div class="instructions">
              {{#if @controller.taken}}
                {{iN "user.change_email.taken"}}
              {{else}}
                {{iN "user.email.instructions"}}
              {{/if}}
            </div>
            <InputTip @validation={{@controller.emailValidation}} />
          </div>
        </div>
        <div class="controls save-button">
          <DButton
            @action={{@controller.saveEmail}}
            @disabled={{@controller.saveDisabled}}
            @translatedLabel={{@controller.saveButtonText}}
            type="submit"
            class="btn-primary"
          />
          <LinkTo
            @route="preferences.account"
            @model={{@controller.model.username}}
            class="cancel"
          >
            {{iN "cancel"}}
          </LinkTo>
        </div>
      {{/if}}
    </form>
  </section>
</template>);
