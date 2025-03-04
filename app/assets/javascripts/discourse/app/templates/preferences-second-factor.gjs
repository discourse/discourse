import RouteTemplate from 'ember-route-template'
import bodyClass from "discourse/helpers/body-class";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import iN from "discourse/helpers/i18n";
import TokenBasedAuthDropdown from "discourse/components/token-based-auth-dropdown";
import DButton from "discourse/components/d-button";
import SecurityKeyDropdown from "discourse/components/security-key-dropdown";
import htmlSafe from "discourse/helpers/html-safe";
import and from "truth-helpers/helpers/and";
import TwoFactorBackupDropdown from "discourse/components/two-factor-backup-dropdown";
import { LinkTo } from "@ember/routing";
export default RouteTemplate(<template>{{bodyClass "user-preferences-page"}}

<section class="user-content user-preferences solo-preference second-factor">
  <ConditionalLoadingSpinner @condition={{@controller.loading}}>
    <form class="form-vertical">
      {{#if @controller.showEnforcedNotice}}
        <div class="alert alert-error">
          {{iN "user.second_factor.enforced_notice"}}
        </div>
      {{/if}}

      {{#if @controller.showEnforcedWithOAuthNotice}}
        <div class="alert alert-error">
          {{iN "user.second_factor.enforced_with_oauth_notice"}}
        </div>
      {{/if}}

      {{#if @controller.displayOAuthWarning}}
        <div class="alert alert-warning">{{iN "user.second_factor.oauth_enabled_warning"}}</div>
      {{/if}}

      {{#if @controller.errorMessage}}
        <div class="alert alert-error">{{@controller.errorMessage}}</div>
      {{/if}}

      <div class="control-group totp">
        <div class="controls">
          <h2>{{iN "user.second_factor.totp.title"}}</h2>
          {{#each @controller.totps as |totp|}}
            <div class="second-factor-item row">
              <div class="details">
                {{#if totp.name}}
                  {{totp.name}}
                {{else}}
                  {{iN "user.second_factor.totp.default_name"}}
                {{/if}}
              </div>
              {{#if @controller.isCurrentUser}}
                <div class="actions">
                  <TokenBasedAuthDropdown @totp={{totp}} @editSecondFactor={{action "editSecondFactor"}} @disableSingleSecondFactor={{action "disableSingleSecondFactor"}} />
                </div>
              {{/if}}
            </div>
          {{/each}}
          <DButton @action={{action "createTotp"}} @icon="plus" @disabled={{@controller.loading}} @label="user.second_factor.totp.add" class="btn-default new-totp" />
        </div>
      </div>

      <div class="control-group security-key">
        <div class="controls">
          <h2>{{iN "user.second_factor.security_key.title"}}</h2>
          {{#each @controller.security_keys as |security_key|}}
            <div class="second-factor-item row">
              <div class="details">
                {{#if security_key.name}}
                  {{security_key.name}}
                {{else}}
                  {{iN "user.second_factor.security_key.default_name"}}
                {{/if}}
              </div>

              {{#if @controller.isCurrentUser}}
                <div class="actions">
                  <SecurityKeyDropdown @securityKey={{security_key}} @editSecurityKey={{action "editSecurityKey"}} @disableSingleSecondFactor={{action "disableSingleSecondFactor"}} />
                </div>
              {{/if}}
            </div>
          {{/each}}
          <DButton @action={{action "createSecurityKey"}} @icon="plus" @disabled={{@controller.loading}} @label="user.second_factor.security_key.add" class="btn-default new-security-key" />
        </div>
      </div>

      <div class="control-group pref-second-factor-backup">
        <div class="controls pref-second-factor-backup">
          <h2>{{iN "user.second_factor_backup.title"}}</h2>
          <div class="second-factor-item row">
            {{#if @controller.model.second_factor_enabled}}
              <div class="details">
                {{#if @controller.model.second_factor_backup_enabled}}
                  {{htmlSafe (iN "user.second_factor_backup.manage" count=@controller.model.second_factor_remaining_backup_codes)}}
                {{else}}
                  <DButton @action={{action "editSecondFactorBackup"}} @icon="plus" @disabled={{@controller.loading}} @label="user.second_factor_backup.enable_long" class="btn-default new-second-factor-backup" />
                {{/if}}
              </div>

              {{#if (and @controller.model.second_factor_backup_enabled @controller.isCurrentUser)}}
                <div class="actions">
                  <TwoFactorBackupDropdown @secondFactorBackupEnabled={{@controller.model.second_factor_backup_enabled}} @editSecondFactorBackup={{action "editSecondFactorBackup"}} @disableSecondFactorBackup={{action "disableSecondFactorBackup"}} />
                </div>
              {{/if}}

            {{else}}
              {{iN "user.second_factor_backup.enable_prerequisites"}}
            {{/if}}
          </div>
        </div>
      </div>

      {{#if @controller.hasSecondFactors}}
        {{#unless @controller.showEnforcedNotice}}
          <div class="control-group pref-second-factor-disable-all">
            <div class="controls -actions">
              <DButton @icon="ban" @action={{action "disableAllSecondFactors"}} @disabled={{@controller.loading}} @label="user.second_factor.disable_all" class="btn-danger" />
              <LinkTo @route="preferences.security" @model={{@controller.model.username}} class="cancel">
                {{iN "cancel"}}
              </LinkTo>
            </div>
          </div>
        {{/unless}}
      {{/if}}
    </form>
  </ConditionalLoadingSpinner>
</section></template>)