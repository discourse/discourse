<DModal
  @closeModal={{@closeModal}}
  @title={{i18n "user.second_factor.security_key.add"}}
  {{did-insert this.securityKeyRequested}}
>
  <:body>
    <ConditionalLoadingSpinner @condition={{this.loading}}>
      {{#if this.errorMessage}}
        <div class="control-group">
          <div class="controls">
            <div class="alert alert-error">{{this.errorMessage}}</div>
          </div>
        </div>
      {{/if}}

      <div class="control-group">
        <div class="controls">
          {{html-safe
            (i18n "user.second_factor.enable_security_key_description")
          }}
        </div>
      </div>

      <div class="control-group">
        <div class="controls">
          <Input
            @value={{this.securityKeyName}}
            id="security-key-name"
            placeholder="security key name"
            maxlength={{this.maxSecondFactorNameLength}}
          />
        </div>
      </div>

      <div class="control-group">
        <div class="controls">
          {{#unless this.webauthnUnsupported}}
            <DButton
              class="btn-primary add-security-key"
              @action={{this.registerSecurityKey}}
              @label="user.second_factor.security_key.register"
            />
          {{/unless}}
        </div>
      </div>
    </ConditionalLoadingSpinner>
  </:body>
</DModal>