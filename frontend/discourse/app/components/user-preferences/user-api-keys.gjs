import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import routeAction from "discourse/helpers/route-action";
import { longDate } from "discourse/lib/formatter";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class UserApiKeyRow extends Component {
  @tracked showScopes = false;

  get isExpired() {
    return (
      this.args.apiKey.expires_at &&
      new Date(this.args.apiKey.expires_at) <= new Date()
    );
  }

  get expiresAtDate() {
    return longDate(this.args.apiKey.expires_at);
  }

  @action
  toggleScopes(event) {
    event?.preventDefault();
    this.showScopes = !this.showScopes;
  }

  <template>
    <div class="row user-api-key">
      <div class="user-api-key__info">
        <div class="user-api-key__name">{{@apiKey.application_name}}</div>
        <div class="user-api-key__dates">
          <div class="user-api-key__date-approved">
            <span>{{i18n "user.api_approved"}}</span>
            {{dAgeWithTooltip @apiKey.created_at format="medium"}}
          </div>
          <div class="user-api-key__date-last-used">
            <span>{{i18n "user.api_last_used_at"}}</span>
            {{dAgeWithTooltip @apiKey.last_used_at format="medium"}}
          </div>
          <div class="user-api-key__date-expires">
            {{#if @apiKey.expires_at}}
              {{#if this.isExpired}}
                <span>{{i18n "user.api_expired_at"}}</span>
              {{else}}
                <span>{{i18n "user.api_expires_at"}}</span>
              {{/if}}
              {{this.expiresAtDate}}
            {{else}}
              <span>{{i18n "user.api_expires_at"}}</span>
              {{i18n "user.api_expires_never"}}
            {{/if}}
          </div>
        </div>
      </div>

      <div class="user-api-key__actions">
        {{#if @apiKey.revoked}}
          <DButton
            @action={{fn (routeAction "undoRevokeApiKey") @apiKey}}
            @label="user.undo_revoke_access"
            class="btn-default btn-small"
          />
        {{else}}
          <DButton
            @action={{fn (routeAction "revokeApiKey") @apiKey}}
            @label="user.revoke_access"
            class="btn-default btn-small"
          />
        {{/if}}
      </div>

      {{#if @apiKey.scopes.length}}
        <div class="user-api-key__scopes-toggle">
          <a href {{on "click" this.toggleScopes}}>
            {{dIcon "caret-down"}}
            <span>{{i18n
                "user.api_show_permissions"
                count=@apiKey.scopes.length
              }}</span>
          </a>
        </div>

        {{#if this.showScopes}}
          <ul class="user-api-key__scopes-list">
            {{#each @apiKey.scopes as |scope|}}
              <li class="user-api-key__scopes-list-item">{{scope}}</li>
            {{/each}}
          </ul>
        {{/if}}
      {{/if}}
    </div>
  </template>
}

const UserApiKeys = <template>
  {{#if @model.userApiKeys}}
    <div class="control-group pref-user-api-keys">
      <label class="control-label pref-user-api-keys__label">{{i18n
          "user.apps"
        }}</label>

      <div class="user-api-keys">
        {{#each @model.userApiKeys as |key|}}
          <UserApiKeyRow @apiKey={{key}} />
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default UserApiKeys;
