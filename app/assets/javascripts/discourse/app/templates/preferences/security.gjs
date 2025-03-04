import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import AuthTokenDropdown from "discourse/components/auth-token-dropdown";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import UserPasskeys from "discourse/components/user-preferences/user-passkeys";
import dIcon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>
  {{#if @controller.canChangePassword}}
    <div class="control-group pref-password" data-setting-name="user-password">
      <label class="control-label">{{iN "user.password.title"}}</label>
      <div class="controls">
        <a
          href
          {{on "click" @controller.changePassword}}
          class="btn btn-default"
        >
          {{dIcon "envelope"}}
          {{#if @controller.model.no_password}}
            {{iN "user.change_password.set_password"}}
          {{else}}
            {{iN "user.change_password.action"}}
          {{/if}}
        </a>

        {{@controller.passwordProgress}}
      </div>
    </div>

    {{#if @controller.canUsePasskeys}}
      <UserPasskeys @model={{@model}} />
    {{/if}}

    {{#if @controller.isCurrentUser}}
      <div
        class="control-group pref-second-factor"
        data-setting-name="user-second-factor"
      >
        <label class="control-label">{{iN "user.second_factor.title"}}</label>
        <div class="instructions">
          {{iN "user.second_factor.short_description"}}
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
      <label class="control-label">{{iN "user.auth_tokens.title"}}</label>
      <div class="instructions">
        {{iN "user.auth_tokens.short_description"}}
      </div>
      <div class="auth-tokens">
        {{#each @controller.authTokens as |token|}}
          <div class="row auth-token">
            <div class="auth-token-icon">{{dIcon token.icon}}</div>
            {{#unless token.is_active}}
              <AuthTokenDropdown
                @token={{token}}
                @revokeAuthToken={{@controller.revokeAuthToken}}
                @showToken={{@controller.showToken}}
              />
            {{/unless}}
            <div class="auth-token-first">
              {{htmlSafe
                (iN
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
                  (iN "user.auth_tokens.browser_active" browser=token.browser)
                }}
              {{else}}
                {{htmlSafe
                  (iN
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
            {{dIcon "caret-up"}}
            <span>{{iN "user.auth_tokens.show_few"}}</span>
          {{else}}
            {{dIcon "caret-down"}}
            <span>
              {{iN
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
        {{dIcon "right-from-bracket"}}
        <span>
          {{iN "user.auth_tokens.log_out_all"}}
        </span>
      </a>
    </div>
  {{/if}}

  <UserApiKeys @model={{@model}} />

  <span>
    <PluginOutlet
      @name="user-preferences-security"
      @connectorTagName="div"
      @outletArgs={{hash model=@controller.model save=(@controller.save)}}
    />
  </span>

  <br />

  <span>
    <PluginOutlet
      @name="user-custom-controls"
      @connectorTagName="div"
      @outletArgs={{hash model=@controller.model}}
    />
  </span>
</template>);
