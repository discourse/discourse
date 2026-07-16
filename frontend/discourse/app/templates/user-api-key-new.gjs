import { on } from "@ember/modifier";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}

  <div class="authorize-api-key">
    {{#if @controller.result}}
      <p>{{@controller.result.instructions}}</p>
      <div class="user-api-key-display">
        <code id="user-api-key-payload">{{@controller.result.payload}}</code>
      </div>
      <div>
        <DButton
          @action={{@controller.copy}}
          @translatedLabel={{i18n @controller.copyButtonLabel}}
          id="copy-api-key-btn"
          class="btn-primary"
        />
      </div>
    {{else}}
      <h1>
        {{#if @controller.page.application_name}}
          {{i18n
            "user_api_key.title"
            application_name=@controller.page.application_name
          }}
        {{else}}
          {{i18n "user_api_key.device.title"}}
        {{/if}}
      </h1>

      {{#if @controller.noTrustLevel}}
        <p class="error-message">{{i18n "user_api_key.no_trust_level"}}</p>
      {{else if @controller.genericError}}
        <p class="error-message">{{i18n "user_api_key.generic_error"}}</p>
      {{else}}
        {{#if @controller.error}}
          <p class="error-message">{{@controller.error}}</p>
        {{/if}}

        <div class="authorize-api-key__user">
          <span class="authorize-api-key__user-label">
            {{i18n "user_api_key.logged_in_as"}}
          </span>
          <img
            class="avatar"
            src={{@controller.avatarUrl}}
            width="24"
            height="24"
            alt=""
          />
          <span class="authorize-api-key__username">
            {{@controller.page.current_user.username}}
          </span>
        </div>

        <div class="authorize-api-key__summary">
          <div class="authorize-api-key__permissions">
            <p class="authorize-api-key__permissions-header">
              {{i18n
                "user_api_key.permissions_header"
                application_name=@controller.page.application_name
              }}
            </p>
            <ul class="authorize-api-key__scopes">
              {{#each @controller.page.localized_scopes as |scope|}}
                <li>{{scope}}</li>
              {{/each}}
            </ul>
          </div>

          {{#if @controller.page.write_scope}}
            <div
              class="authorize-api-key__write-warning authorize-api-key__summary-notice"
            >
              <p>{{i18n "user_api_key.write_scope_warning"}}</p>
            </div>
          {{/if}}

          {{#if @controller.expiresAt}}
            <div
              class="authorize-api-key__expiry authorize-api-key__summary-detail"
            >
              <p>
                {{i18n
                  "user_api_key.expiry_notice"
                  application_name=@controller.page.application_name
                  expires_at=@controller.expiresAt
                }}
              </p>
            </div>
          {{/if}}
        </div>

        {{#if @controller.page.redirect_uri}}
          <div class="authorize-api-key__redirect">
            <p class="authorize-api-key__redirect-url">
              {{i18n "user_api_key.redirect_warning"}}
              <strong>{{@controller.page.redirect_uri}}</strong>
            </p>
          </div>
        {{/if}}

        <form {{on "submit" @controller.authorize}}>
          <div class="authorize-api-key__buttons">
            <DButton
              @isLoading={{@controller.isLoading}}
              @action={{@controller.authorize}}
              @label="user_api_key.authorize"
              type="submit"
              class="btn-primary"
            />
            <DButton @href="/" @label="user_api_key.deny" class="btn-default" />
          </div>
        </form>
      {{/if}}
    {{/if}}
  </div>
</template>
