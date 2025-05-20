import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import AuthTokenDropdown from "discourse/components/auth-token-dropdown";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import UserPasskeys from "discourse/components/user-preferences/user-passkeys";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.canChangePassword}}
      <div
        class="control-group pref-password"
        data-setting-name="user-password"
      >
        <label class="control-label">{{i18n "user.password.title"}}</label>
        <div class="controls">
          <a
            href
            {{on "click" @controller.changePassword}}
            class="btn btn-default"
            id="change-password-button"
          >
            {{icon "envelope"}}
            {{#if @controller.model.no_password}}
              {{i18n "user.change_password.set_password"}}
            {{else}}
              {{i18n "user.change_password.action"}}
            {{/if}}
          </a>

          {{@controller.passwordProgress}}
        </div>

        {{#unless @controller.model.no_password}}
          {{#if @controller.associatedAccountsLoaded}}
            {{#if @controller.canRemovePassword}}
              <div class="controls">
                <a
                  href
                  {{on "click" @controller.removePassword}}
                  hidden={{@controller.removePasswordInProgress}}
                  id="remove-password-link"
                >
                  {{icon "trash-can"}}
                  {{i18n "user.change_password.remove"}}
                </a>
              </div>
            {{/if}}
          {{else}}
            <div class="controls">
              <DButton
                @action={{fn (routeAction "checkEmail") @controller.model}}
                @title="admin.users.check_email.title"
                @icon="envelope"
                @label="admin.users.check_email.text"
              />
            </div>
          {{/if}}
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
          <label class="control-label">{{i18n
              "user.second_factor.title"
            }}</label>
          <div class="instructions">
            {{i18n "user.second_factor.short_description"}}
          </div>

          <div class="controls pref-second-factor">
            <DButton
              @action={{@controller.manage2FA}}
              @icon="lock"
              @label="user.second_factor.enable"
              class="btn-default btn-second-factor"
            />
          </div>
        </div>
      {{/if}}
    {{/if}}

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
              <div class="auth-token-icon">{{icon token.icon}}</div>
              {{#unless token.is_active}}
                <AuthTokenDropdown
                  @token={{token}}
                  @revokeAuthToken={{@controller.revokeAuthToken}}
                  @showToken={{@controller.showToken}}
                />
              {{/unless}}
              <div class="auth-token-first">
                {{htmlSafe
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
                  {{htmlSafe
                    (i18n
                      "user.auth_tokens.browser_active" browser=token.browser
                    )
                  }}
                {{else}}
                  {{htmlSafe
                    (i18n
                      "user.auth_tokens.browser_last_seen"
                      browser=token.browser
                      date=(formatDate token.seen_at)
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
              {{icon "caret-up"}}
              <span>{{i18n "user.auth_tokens.show_few"}}</span>
            {{else}}
              {{icon "caret-down"}}
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
          href
          {{on "click" (fn @controller.revokeAuthToken null)}}
          class="pull-right text-danger"
        >
          {{icon "right-from-bracket"}}
          <span>
            {{i18n "user.auth_tokens.log_out_all"}}
          </span>
        </a>
      </div>
    {{/if}}

    <UserApiKeys @model={{@model}} />

    <span>
      <PluginOutlet
        @name="user-preferences-security"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model save=this.save}}
      />
    </span>

    <br />

    <span>
      <PluginOutlet
        @name="user-custom-controls"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>
  </template>
);
