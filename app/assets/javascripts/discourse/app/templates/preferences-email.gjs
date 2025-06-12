import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import InputTip from "discourse/components/input-tip";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "user-preferences-page"}}
    <PluginOutlet
      @name="preferences-email-wrapper"
      @outletArgs={{lazyHash model=this.model}}
    >
      <section class="user-content user-preferences solo-preference">
        <form class="form-vertical">
          {{#if @controller.success}}
            <div
              class="alert alert-success"
            >{{@controller.successMessage}}</div>
            <LinkTo @route="preferences.account" class="success-back">
              {{icon "arrow-left"}}
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
                <TextField
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
                {{i18n "cancel"}}
              </LinkTo>
            </div>
          {{/if}}
        </form>
      </section>
    </PluginOutlet>
  </template>
);
