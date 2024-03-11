<DModal
  @closeModal={{@closeModal}}
  @title={{i18n "user.second_factor.totp.add"}}
  {{did-insert this.totpRequested}}
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
          {{html-safe (i18n "user.second_factor.enable_description")}}
        </div>
      </div>

      <div class="control-group">
        <div class="controls">
          <div class="qr-code">
            <img src={{html-safe this.secondFactorImage}} />
          </div>
          <p>
            {{#if this.showSecondFactorKey}}
              <div class="second-factor-key">
                {{this.secondFactorKey}}
              </div>
            {{else}}
              <a
                href
                class="show-second-factor-key"
                {{on "click" this.enableShowSecondFactorKey}}
              >{{i18n "user.second_factor.show_key_description"}}</a>
            {{/if}}
          </p>
        </div>
      </div>

      <div class="control-group">
        <label class="control-label input-prepend">{{i18n
            "user.second_factor.name"
          }}</label>
        <div class="controls">
          <input
            {{on "input" (with-event-value (fn (mut this.secondFactorName)))}}
            value={{this.secondFactorName}}
            type="text"
            placeholder={{i18n "user.second_factor.totp.default_name"}}
            maxlength={{this.maxSecondFactorNameLength}}
            id="second-factor-name"
          />
        </div>

        <label class="control-label input-prepend">
          {{i18n "user.second_factor.label"}}
        </label>
        <div class="controls">
          <SecondFactorInput
            {{on "input" (with-event-value (fn (mut this.secondFactorToken)))}}
            @secondFactorMethod={{this.totpType}}
            value={{this.secondFactorToken}}
            placeholder="123456"
            id="second-factor-token"
          />
        </div>
      </div>

      <div class="control-group">
        <div class="controls">
          <DButton
            class="btn-primary add-totp"
            @action={{this.enableSecondFactor}}
            @label="enable"
          />
        </div>
      </div>
    </ConditionalLoadingSpinner>
  </:body>
</DModal>