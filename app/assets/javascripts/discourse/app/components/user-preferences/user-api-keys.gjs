import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import boundDate from "discourse/helpers/bound-date";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

const UserApiKeys = <template>
  {{#if @model.userApiKeys}}
    <div class="control-group pref-user-api-keys">
      <label class="control-label pref-user-api-keys__label">{{i18n
          "user.apps"
        }}</label>

      <div class="controls">
        {{#each @model.userApiKeys as |key|}}
          <div>
            <span
              class="pref-user-api-keys__application-name"
            >{{key.application_name}}</span>

            {{#if key.revoked}}
              <DButton
                @action={{fn (routeAction "undoRevokeApiKey") key}}
                @label="user.undo_revoke_access"
              />
            {{else}}
              <DButton
                @action={{fn (routeAction "revokeApiKey") key}}
                @label="user.revoke_access"
              />
            {{/if}}

            <p>
              <ul class="pref-user-api-keys__scopes-list">
                {{#each key.scopes as |scope|}}
                  <li
                    class="pref-user-api-keys__scopes-list-item"
                  >{{scope}}</li>
                {{/each}}
              </ul>
            </p>

            <p class="pref-user-api-keys__created-at">
              <span>{{i18n "user.api_approved"}}</span>
              {{boundDate key.created_at}}
            </p>

            <p class="pref-user-api-keys__last-used-at">
              <span>{{i18n "user.api_last_used_at"}}</span>
              {{boundDate key.last_used_at}}
            </p>
          </div>
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;
export default UserApiKeys;
