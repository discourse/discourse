import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecondFactorInput from "discourse/components/second-factor-input";
import SecurityKeyForm from "discourse/components/security-key-form";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="container email-login clearfix">
      <div class="content-wrapper">
        <div class="image-wrapper">
          <img
            src={{@controller.lockImageUrl}}
            class="password-reset-img"
            alt
          />
        </div>

        <form>
          {{#if @controller.model.error}}
            <div class="error-info">
              {{htmlSafe @controller.model.error}}
            </div>
          {{/if}}

          {{#if @controller.model.can_login}}
            <div class="email-login-form">
              {{#if @controller.secondFactorRequired}}
                {{#if @controller.model.security_key_required}}
                  <SecurityKeyForm
                    @setShowSecurityKey={{fn
                      (mut @controller.model.security_key_required)
                    }}
                    @setSecondFactorMethod={{fn
                      (mut @controller.secondFactorMethod)
                    }}
                    @backupEnabled={{@controller.model.backup_codes_enabled}}
                    @totpEnabled={{@controller.model.totp_enabled}}
                    @otherMethodAllowed={{@controller.secondFactorRequired}}
                    @action={{@controller.authenticateSecurityKey}}
                  />
                {{else}}
                  <SecondFactorForm
                    @secondFactorMethod={{@controller.secondFactorMethod}}
                    @secondFactorToken={{@controller.secondFactorToken}}
                    @backupEnabled={{@controller.model.backup_codes_enabled}}
                    @totpEnabled={{@controller.model.totp_enabled}}
                    @isLogin={{true}}
                  >
                    <SecondFactorInput
                      {{on
                        "input"
                        (withEventValue
                          (fn (mut @controller.secondFactorToken))
                        )
                      }}
                      @secondFactorMethod={{@controller.secondFactorMethod}}
                      value={{@controller.secondFactorToken}}
                    />
                  </SecondFactorForm>
                {{/if}}
              {{else}}
                <h2>{{i18n
                    "email_login.confirm_title"
                    site_name=@controller.siteSettings.title
                  }}</h2>
                <p>{{i18n
                    "email_login.logging_in_as"
                    email=@controller.model.token_email
                  }}</p>
              {{/if}}

              {{#unless @controller.model.security_key_required}}
                <DButton
                  @label="email_login.confirm_button"
                  @action={{@controller.finishLogin}}
                  type="submit"
                  class="btn-primary"
                />
              {{/unless}}
            </div>
          {{/if}}
        </form>
      </div>
    </div>
  </template>
);
