import { LinkTo } from "@ember/routing";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import DInputTip from "discourse/ui-kit/d-input-tip";
import DTextField from "discourse/ui-kit/d-text-field";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "user-preferences-page"}}
  <PluginOutlet
    @name="preferences-email-wrapper"
    @outletArgs={{lazyHash model=this.model}}
  >
    <section class="user-content user-preferences solo-preference">
      <form class="form-vertical">
        {{#if @controller.success}}
          <div class="alert alert-success">{{@controller.successMessage}}</div>
          <LinkTo @route="preferences.account" class="success-back">
            {{dIcon "arrow-left"}}
            {{i18n "user.change_email.back_to_preferences"}}
          </LinkTo>
        {{else}}
          {{#if @controller.error}}
            <div class="alert alert-error">{{@controller.errorMessage}}</div>
          {{/if}}
          <div class="control-group">
            <label class="control-label">
              {{i18n
                (if
                  @controller.new
                  "user.add_email.title"
                  "user.change_email.title"
                )
              }}
            </label>
            <div class="controls">
              <DTextField
                @value={{@controller.newEmail}}
                @id="change-email"
                @classNames="input-xxlarge"
                @autofocus="autofocus"
              />
              <div class="instructions">
                {{#if @controller.taken}}
                  {{i18n "user.change_email.taken"}}
                {{else}}
                  {{i18n "user.email.instructions"}}
                {{/if}}
              </div>
              <DInputTip @validation={{@controller.emailValidation}} />
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
              {{i18n "cancel"}}
            </LinkTo>
          </div>
        {{/if}}
      </form>
    </section>
  </PluginOutlet>
</template>
