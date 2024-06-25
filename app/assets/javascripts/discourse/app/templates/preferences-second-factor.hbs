{{body-class "user-preferences-page"}}

<section class="user-content user-preferences solo-preference second-factor">
  <ConditionalLoadingSpinner @condition={{this.loading}}>
    <form class="form-vertical">
      {{#if this.showEnforcedNotice}}
        <div class="alert alert-error">
          {{i18n "user.second_factor.enforced_notice"}}
        </div>
      {{/if}}

      {{#if this.showEnforcedWithOAuthNotice}}
        <div class="alert alert-error">
          {{i18n "user.second_factor.enforced_with_oauth_notice"}}
        </div>
      {{/if}}

      {{#if this.displayOAuthWarning}}
        <div class="alert alert-warning">{{i18n
            "user.second_factor.oauth_enabled_warning"
          }}</div>
      {{/if}}

      {{#if this.errorMessage}}
        <div class="alert alert-error">{{this.errorMessage}}</div>
      {{/if}}

      <div class="control-group totp">
        <div class="controls">
          <h2>{{i18n "user.second_factor.totp.title"}}</h2>
          {{#each this.totps as |totp|}}
            <div class="second-factor-item row">
              <div class="details">
                {{#if totp.name}}
                  {{totp.name}}
                {{else}}
                  {{i18n "user.second_factor.totp.default_name"}}
                {{/if}}
              </div>
              {{#if this.isCurrentUser}}
                <div class="actions">
                  <TokenBasedAuthDropdown
                    @totp={{totp}}
                    @editSecondFactor={{action "editSecondFactor"}}
                    @disableSingleSecondFactor={{action
                      "disableSingleSecondFactor"
                    }}
                  />
                </div>
              {{/if}}
            </div>
          {{/each}}
          <DButton
            @action={{action "createTotp"}}
            @icon="plus"
            @disabled={{this.loading}}
            @label="user.second_factor.totp.add"
            class="btn-default new-totp"
          />
        </div>
      </div>

      <div class="control-group security-key">
        <div class="controls">
          <h2>{{i18n "user.second_factor.security_key.title"}}</h2>
          {{#each this.security_keys as |security_key|}}
            <div class="second-factor-item row">
              <div class="details">
                {{#if security_key.name}}
                  {{security_key.name}}
                {{else}}
                  {{i18n "user.second_factor.security_key.default_name"}}
                {{/if}}
              </div>

              {{#if this.isCurrentUser}}
                <div class="actions">
                  <SecurityKeyDropdown
                    @securityKey={{security_key}}
                    @editSecurityKey={{action "editSecurityKey"}}
                    @disableSingleSecondFactor={{action
                      "disableSingleSecondFactor"
                    }}
                  />
                </div>
              {{/if}}
            </div>
          {{/each}}
          <DButton
            @action={{action "createSecurityKey"}}
            @icon="plus"
            @disabled={{this.loading}}
            @label="user.second_factor.security_key.add"
            class="btn-default new-security-key"
          />
        </div>
      </div>

      <div class="control-group pref-second-factor-backup">
        <div class="controls pref-second-factor-backup">
          <h2>{{i18n "user.second_factor_backup.title"}}</h2>
          <div class="second-factor-item row">
            {{#if this.model.second_factor_enabled}}
              <div class="details">
                {{#if this.model.second_factor_backup_enabled}}
                  {{html-safe
                    (i18n
                      "user.second_factor_backup.manage"
                      count=this.model.second_factor_remaining_backup_codes
                    )
                  }}
                {{else}}
                  <DButton
                    @action={{action "editSecondFactorBackup"}}
                    @icon="plus"
                    @disabled={{this.loading}}
                    @label="user.second_factor_backup.enable_long"
                    class="btn-default new-second-factor-backup"
                  />
                {{/if}}
              </div>

              {{#if
                (and this.model.second_factor_backup_enabled this.isCurrentUser)
              }}
                <div class="actions">
                  <TwoFactorBackupDropdown
                    @secondFactorBackupEnabled={{this.model.second_factor_backup_enabled}}
                    @editSecondFactorBackup={{action "editSecondFactorBackup"}}
                    @disableSecondFactorBackup={{action
                      "disableSecondFactorBackup"
                    }}
                  />
                </div>
              {{/if}}

            {{else}}
              {{i18n "user.second_factor_backup.enable_prerequisites"}}
            {{/if}}
          </div>
        </div>
      </div>

      {{#if this.hasSecondFactors}}
        {{#unless this.showEnforcedNotice}}
          <div class="control-group pref-second-factor-disable-all">
            <div class="controls -actions">
              <DButton
                @icon="ban"
                @action={{action "disableAllSecondFactors"}}
                @disabled={{this.loading}}
                @label="user.second_factor.disable_all"
                class="btn-danger"
              />
              <LinkTo
                @route="preferences.security"
                @model={{this.model.username}}
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