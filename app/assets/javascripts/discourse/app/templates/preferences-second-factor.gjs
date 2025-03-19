import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import SecurityKeyDropdown from "discourse/components/security-key-dropdown";
import TokenBasedAuthDropdown from "discourse/components/token-based-auth-dropdown";
import TwoFactorBackupDropdown from "discourse/components/two-factor-backup-dropdown";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "user-preferences-page"}}

    <section
      class="user-content user-preferences solo-preference second-factor"
    >
      <ConditionalLoadingSpinner @condition={{@controller.loading}}>
        <form class="form-vertical">
          {{#if @controller.showEnforcedNotice}}
            <div class="alert alert-error">
              {{i18n "user.second_factor.enforced_notice"}}
            </div>
          {{/if}}

          {{#if @controller.showEnforcedWithOAuthNotice}}
            <div class="alert alert-error">
              {{i18n "user.second_factor.enforced_with_oauth_notice"}}
            </div>
          {{/if}}

          {{#if @controller.displayOAuthWarning}}
            <div class="alert alert-warning">{{i18n
                "user.second_factor.oauth_enabled_warning"
              }}</div>
          {{/if}}

          {{#if @controller.errorMessage}}
            <div class="alert alert-error">{{@controller.errorMessage}}</div>
          {{/if}}

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
                  {{#if @controller.isCurrentUser}}
                    <div class="actions">
                      <TokenBasedAuthDropdown
                        @totp={{totp}}
                        @editSecondFactor={{@controller.editSecondFactor}}
                        @disableSingleSecondFactor={{@controller.disableSingleSecondFactor}}
                      />
                    </div>
                  {{/if}}
                </div>
              {{/each}}
              <DButton
                @action={{@controller.createTotp}}
                @icon="plus"
                @disabled={{@controller.loading}}
                @label="user.second_factor.totp.add"
                class="btn-default new-totp"
              />
            </div>
          </div>

          <div class="control-group security-key">
            <div class="controls">
              <h2>{{i18n "user.second_factor.security_key.title"}}</h2>
              {{#each @controller.security_keys as |security_key|}}
                <div class="second-factor-item row">
                  <div class="details">
                    {{#if security_key.name}}
                      {{security_key.name}}
                    {{else}}
                      {{i18n "user.second_factor.security_key.default_name"}}
                    {{/if}}
                  </div>

                  {{#if @controller.isCurrentUser}}
                    <div class="actions">
                      <SecurityKeyDropdown
                        @securityKey={{security_key}}
                        @editSecurityKey={{@controller.editSecurityKey}}
                        @disableSingleSecondFactor={{@controller.disableSingleSecondFactor}}
                      />
                    </div>
                  {{/if}}
                </div>
              {{/each}}
              <DButton
                @action={{@controller.createSecurityKey}}
                @icon="plus"
                @disabled={{@controller.loading}}
                @label="user.second_factor.security_key.add"
                class="btn-default new-security-key"
              />
            </div>
          </div>

          <div class="control-group pref-second-factor-backup">
            <div class="controls pref-second-factor-backup">
              <h2>{{i18n "user.second_factor_backup.title"}}</h2>
              <div class="second-factor-item row">
                {{#if @controller.model.second_factor_enabled}}
                  <div class="details">
                    {{#if @controller.model.second_factor_backup_enabled}}
                      {{htmlSafe
                        (i18n
                          "user.second_factor_backup.manage"
                          count=@controller.model.second_factor_remaining_backup_codes
                        )
                      }}
                    {{else}}
                      <DButton
                        @action={{@controller.editSecondFactorBackup}}
                        @icon="plus"
                        @disabled={{@controller.loading}}
                        @label="user.second_factor_backup.enable_long"
                        class="btn-default new-second-factor-backup"
                      />
                    {{/if}}
                  </div>

                  {{#if
                    (and
                      @controller.model.second_factor_backup_enabled
                      @controller.isCurrentUser
                    )
                  }}
                    <div class="actions">
                      <TwoFactorBackupDropdown
                        @secondFactorBackupEnabled={{@controller.model.second_factor_backup_enabled}}
                        @editSecondFactorBackup={{@controller.editSecondFactorBackup}}
                        @disableSecondFactorBackup={{@controller.disableSecondFactorBackup}}
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
            {{#unless @controller.showEnforcedNotice}}
              <div class="control-group pref-second-factor-disable-all">
                <div class="controls -actions">
                  <DButton
                    @icon="ban"
                    @action={{@controller.disableAllSecondFactors}}
                    @disabled={{@controller.loading}}
                    @label="user.second_factor.disable_all"
                    class="btn-danger"
                  />
                  <LinkTo
                    @route="preferences.security"
                    @model={{@controller.model.username}}
                    class="cancel"
                  >
                    {{i18n "cancel"}}
                  </LinkTo>
                </div>
              </div>
            {{/unless}}
          {{/if}}
        </form>
      </ConditionalLoadingSpinner>
    </section>
  </template>
);
