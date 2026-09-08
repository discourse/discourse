import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import AuthTokenDropdown from "discourse/components/auth-token-dropdown";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import UserPasskeys from "discourse/components/user-preferences/user-passkeys";
import lazyHash from "discourse/helpers/lazy-hash";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.canChangePassword}}
    <div class="control-group pref-password" data-setting-name="user-password">
      <label class="control-label">{{i18n "user.password.title"}}</label>
      <div class="controls">
        <button
          class="btn btn-default"
          disabled={{not @controller.canResetPassword}}
          id="change-password-button"
          {{on "click" @controller.changePassword}}
        >
          {{dIcon "envelope"}}
          {{#if @controller.model.no_password}}
            {{i18n "user.change_password.set_password"}}
          {{else}}
            {{i18n "user.change_password.action"}}
          {{/if}}
        </button>

        {{#unless @controller.canResetPassword}}
          <div class="instructions">
            {{i18n "user.change_password.staged_user"}}
          </div>
        {{/unless}}

        {{@controller.passwordProgress}}
      </div>

      {{#unless @controller.model.no_password}}
        <div class="controls">
          <button
            class="btn btn-danger"
            disabled={{not @controller.canRemovePassword}}
            hidden={{@controller.removePasswordInProgress}}
            id="remove-password-link"
            {{on "click" @controller.removePassword}}
          >
            {{dIcon "trash-can"}}
            {{i18n "user.change_password.remove"}}
          </button>
        </div>

        {{#unless @controller.canRemovePassword}}
          <div class="instructions">
            {{i18n "user.change_password.remove_disabled"}}
          </div>
        {{/unless}}
      {{/unless}}
    </div>

    {{#if @controller.canUsePasskeys}}
      <UserPasskeys @model={{@model}} />
    {{/if}}

    {{#if @controller.isCurrentUser}}
      <div
        class="control-group pref-second-factor"
        data-setting-name="user-second-factor"
      >
        <label class="control-label">{{i18n "user.second_factor.title"}}</label>
        <div class="instructions">
          {{i18n "user.second_factor.short_description"}}
        </div>

        <div class="controls pref-second-factor">
          <DButton
            class="btn-default btn-second-factor"
            @action={{@controller.manage2FA}}
            @icon="lock"
            @label="user.second_factor.enable"
          />
        </div>
      </div>
    {{/if}}
  {{/if}}

  <PluginOutlet @name="user-preferences-security-after-password" />

  {{#if @controller.canCheckEmails}}
    <div
      class="control-group pref-auth-tokens"
      data-setting-name="user-auth-tokens"
    >
      <label class="control-label">{{i18n "user.auth_tokens.title"}}</label>
      <div class="instructions">
        {{i18n "user.auth_tokens.short_description"}}
      </div>
      <div class="auth-tokens">
        {{#each @controller.authTokens as |token|}}
          <div class="row auth-token">
            <div class="auth-token-icon">{{dIcon token.icon}}</div>
            {{#unless token.is_active}}
              <AuthTokenDropdown
                @revokeAuthToken={{@controller.revokeAuthToken}}
                @showToken={{@controller.showToken}}
                @token={{token}}
              />
            {{/unless}}
            <div class="auth-token-first">
              {{trustHTML
                (i18n
                  "user.auth_tokens.device_location"
                  device=token.device
                  ip=token.client_ip
                  location=token.location
                )
              }}
            </div>
            <div class="auth-token-second">
              {{#if token.is_active}}
                {{trustHTML
                  (i18n "user.auth_tokens.browser_active" browser=token.browser)
                }}
              {{else}}
                {{trustHTML
                  (i18n
                    "user.auth_tokens.browser_last_seen"
                    browser=token.browser
                    date=(dFormatDate token.seen_at)
                  )
                }}
              {{/if}}
            </div>
          </div>
        {{/each}}
      </div>

      {{#if @controller.canShowAllAuthTokens}}
        <a href {{on "click" @controller.toggleShowAllAuthTokens}}>
          {{#if @controller.showAllAuthTokens}}
            {{dIcon "angle-up"}}
            <span>{{i18n "user.auth_tokens.show_few"}}</span>
          {{else}}
            {{dIcon "angle-down"}}
            <span>
              {{i18n
                "user.auth_tokens.show_all"
                count=@controller.model.user_auth_tokens.length
              }}
            </span>
          {{/if}}
        </a>
      {{/if}}

      <a
        class="pull-right text-danger"
        href
        {{on "click" (fn @controller.revokeAuthToken null)}}
      >
        {{dIcon "right-from-bracket"}}
        <span>
          {{i18n "user.auth_tokens.log_out_all"}}
        </span>
      </a>
    </div>
  {{/if}}

  <UserApiKeys @model={{@model}} />

  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-preferences-security"
      @outletArgs={{lazyHash model=@controller.model save=this.save}}
    />
  </span>

  <br />

  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-custom-controls"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>
</template>
