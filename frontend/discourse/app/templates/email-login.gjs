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
        <img src={{@controller.lockImageUrl}} class="password-reset-img" alt />
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
              {{#if @controller.showWebauthnForm}}
                <SecurityKeyForm
                  @setShowSecondFactor={{fn (mut @controller.showTokenInput)}}
                  @setSecondFactorMethod={{fn
                    (mut @controller.secondFactorMethod)
                  }}
                  @backupEnabled={{@controller.model.backup_codes_enabled}}
                  @totpEnabled={{@controller.model.totp_enabled}}
                  @otherMethodAllowed={{@controller.otherTokenMethodsAllowed}}
                  @passkeysEnabled={{@controller.model.passkeys_enabled}}
                  @securityKeysEnabled={{@controller.model.security_key_required}}
                  @passkeyAction={{@controller.authenticatePasskey}}
                  @securityKeyAction={{@controller.authenticateSecurityKey}}
                />
              {{else}}
                <SecondFactorForm
                  @secondFactorMethod={{@controller.secondFactorMethod}}
                  @secondFactorToken={{@controller.secondFactorToken}}
                  @backupEnabled={{@controller.model.backup_codes_enabled}}
                  @totpEnabled={{@controller.model.totp_enabled}}
                  @isLogin={{true}}
                >
                  <DSecondFactorInput
                    @onChange={{fn (mut @controller.secondFactorToken)}}
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

            {{#unless @controller.showWebauthnForm}}
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
