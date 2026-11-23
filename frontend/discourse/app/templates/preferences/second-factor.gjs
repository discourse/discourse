import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import SecurityKeyDropdown from "discourse/components/security-key-dropdown";
import TokenBasedAuthDropdown from "discourse/components/token-based-auth-dropdown";
import TwoFactorBackupDropdown from "discourse/components/two-factor-backup-dropdown";
import bodyClass from "discourse/helpers/body-class";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet @name="user-second-factor-wrapper">
    {{bodyClass "user-preferences-page"}}

    <section
      class="user-content user-preferences solo-preference second-factor"
    >
      <DConditionalLoadingSpinner @condition={{@controller.loading}}>
        {{#if @controller.model.enforcedSecondFactor}}
          <div class="alert alert-error">
            {{i18n "user.second_factor.enforced_notice"}}
          </div>
        {{/if}}

        {{#if @controller.externalLoginRequired}}
          <div class="alert alert-error second-factor__external-login-required">
            {{i18n "user.second_factor.external_login_required"}}
          </div>
          <DButton
            class="btn-primary second-factor__sign-out"
            @action={{routeAction "logout"}}
            @label="user.log_out"
          />
        {{else if @controller.localConfirmationRequired}}
          <DButton
            class="btn-primary"
            @action={{@controller.confirmLocalSession}}
            @label="user.confirm_access.title"
          />
        {{else if @controller.factorsLoaded}}
          <form class="form-vertical">

            <PluginOutlet @name="user-second-factor-totp-wrapper">
              <div class="control-group totp">
                <div class="controls">
                  <h2>{{i18n "user.second_factor.totp.title"}}</h2>
                  {{#each @controller.totps as |totp|}}
                    <div class="second-factor-item row">
                      <div class="details">
                        {{#if totp.name}}
                          {{totp.name}}
                        {{else}}
                          {{i18n "user.second_factor.totp.default_name"}}
                        {{/if}}
                      </div>
                      <div class="actions">
                        <TokenBasedAuthDropdown
                          @disableSingleSecondFactor={{@controller.disableSingleSecondFactor}}
                          @editSecondFactor={{@controller.editSecondFactor}}
                          @totp={{totp}}
                        />
                      </div>
                    </div>
                  {{/each}}
                  <DButton
                    class="btn-default new-totp"
                    @action={{@controller.createTotp}}
                    @disabled={{@controller.loading}}
                    @icon="plus"
                    @label="user.second_factor.totp.add"
                  />
                </div>
              </div>
            </PluginOutlet>

            <PluginOutlet @name="user-second-factor-security-key-wrapper">
              <div class="control-group security-key">
                <div class="controls">
                  <h2>{{i18n "user.second_factor.security_key.title"}}</h2>
                  {{#each @controller.security_keys as |security_key|}}
                    <div class="second-factor-item row">
                      <div class="details">
                        {{#if security_key.name}}
                          {{security_key.name}}
                        {{else}}
                          {{i18n
                            "user.second_factor.security_key.default_name"
                          }}
                        {{/if}}
                      </div>

                      <div class="actions">
                        <SecurityKeyDropdown
                          @disableSingleSecondFactor={{@controller.disableSingleSecondFactor}}
                          @editSecurityKey={{@controller.editSecurityKey}}
                          @securityKey={{security_key}}
                        />
                      </div>
                    </div>
                  {{/each}}
                  <DButton
                    class="btn-default new-security-key"
                    @action={{@controller.createSecurityKey}}
                    @disabled={{@controller.loading}}
                    @icon="plus"
                    @label="user.second_factor.security_key.add"
                  />
                </div>
              </div>
            </PluginOutlet>

            <div class="control-group pref-second-factor-backup">
              <div class="controls pref-second-factor-backup">
                <h2>{{i18n "user.second_factor_backup.title"}}</h2>
                <div class="second-factor-item row">
                  {{#if @controller.model.second_factor_enabled}}
                    <div class="details">
                      {{#if @controller.model.second_factor_backup_enabled}}
                        {{trustHTML
                          (i18n
                            "user.second_factor_backup.manage"
                            count=@controller.model.second_factor_remaining_backup_codes
                          )
                        }}
                      {{else}}
                        <DButton
                          class="btn-default new-second-factor-backup"
                          @action={{@controller.editSecondFactorBackup}}
                          @disabled={{@controller.loading}}
                          @icon="plus"
                          @label="user.second_factor_backup.enable_long"
                        />
                      {{/if}}
                    </div>

                    {{#if @controller.model.second_factor_backup_enabled}}
                      <div class="actions">
                        <TwoFactorBackupDropdown
                          @disableSecondFactorBackup={{@controller.disableSecondFactorBackup}}
                          @editSecondFactorBackup={{@controller.editSecondFactorBackup}}
                          @secondFactorBackupEnabled={{@controller.model.second_factor_backup_enabled}}
                        />
                      </div>
                    {{/if}}

                  {{else}}
                    {{i18n "user.second_factor_backup.enable_prerequisites"}}
                  {{/if}}
                </div>
              </div>
            </div>

            {{#if @controller.hasSecondFactors}}
              {{#unless @controller.model.requiresSecondFactor}}
                <div class="control-group pref-second-factor-disable-all">
                  <div class="controls -actions">
                    <DButton
                      class="btn-danger"
                      @action={{@controller.disableAllSecondFactors}}
                      @disabled={{@controller.loading}}
                      @icon="ban"
                      @label="user.second_factor.disable_all"
                    />
                  </div>
                </div>
              {{/unless}}
            {{/if}}
          </form>
        {{else if @controller.errorMessage}}
          <div class="alert alert-error second-factor__load-error">
            {{@controller.errorMessage}}
          </div>
        {{/if}}

        {{#unless @controller.model.enforcedSecondFactor}}
          <LinkTo
            class="cancel"
            @model={{@controller.model.username}}
            @route="preferences.security"
          >
            {{i18n "cancel"}}
          </LinkTo>
        {{/unless}}
      </DConditionalLoadingSpinner>
    </section>
  </PluginOutlet>
</template>
