import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecurityKeyForm from "discourse/components/security-key-form";
import DButton from "discourse/ui-kit/d-button";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="container email-login clearfix">
    <div class="content-wrapper">
      <div class="image-wrapper">
        <img alt class="password-reset-img" src={{@controller.lockImageUrl}} />
      </div>

      <form>
        {{#if @controller.model.error}}
          <div class="error-info">
            {{trustHTML @controller.model.error}}
          </div>
        {{/if}}

        {{#if @controller.model.can_login}}
          <div class="email-login-form">
            {{#if @controller.secondFactorRequired}}
              {{#if @controller.model.security_key_required}}
                <SecurityKeyForm
                  @action={{@controller.authenticateSecurityKey}}
                  @backupEnabled={{@controller.model.backup_codes_enabled}}
                  @otherMethodAllowed={{@controller.secondFactorRequired}}
                  @setSecondFactorMethod={{fn
                    (mut @controller.secondFactorMethod)
                  }}
                  @setShowSecurityKey={{fn
                    (mut @controller.model.security_key_required)
                  }}
                  @totpEnabled={{@controller.model.totp_enabled}}
                />
              {{else}}
                <SecondFactorForm
                  @backupEnabled={{@controller.model.backup_codes_enabled}}
                  @isLogin={{true}}
                  @secondFactorMethod={{@controller.secondFactorMethod}}
                  @secondFactorToken={{@controller.secondFactorToken}}
                  @totpEnabled={{@controller.model.totp_enabled}}
                >
                  <DSecondFactorInput
                    value={{@controller.secondFactorToken}}
                    @onChange={{fn (mut @controller.secondFactorToken)}}
                    @secondFactorMethod={{@controller.secondFactorMethod}}
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
                class="btn-primary"
                type="submit"
                @action={{@controller.finishLogin}}
                @label="email_login.confirm_button"
              />
            {{/unless}}
          </div>
        {{/if}}
      </form>
    </div>
  </div>
</template>
