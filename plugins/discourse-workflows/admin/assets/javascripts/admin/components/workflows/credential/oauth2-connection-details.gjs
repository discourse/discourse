import { and, eq, not } from "discourse/truth-helpers";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import { i18n } from "discourse-i18n";

const OAuth2ConnectionDetails = <template>
  <div class="workflows-credential-connection" ...attributes>
    <strong class="workflows-credential-connection__status">
      {{#if (eq @connection.status "connected")}}
        {{i18n "discourse_workflows.oauth2.statuses.connected"}}
      {{else if (eq @connection.status "reconnect_required")}}
        {{i18n "discourse_workflows.oauth2.statuses.reconnect_required"}}
      {{else}}
        {{i18n "discourse_workflows.oauth2.statuses.not_connected"}}
      {{/if}}
    </strong>
    {{#if (and (not @compact) @connection.last_refreshed_at)}}
      <dl class="workflows-credential-connection__details">
        {{#each @connection.details as |detail|}}
          <dt>{{detail.label}}</dt>
          <dd>{{detail.value}}</dd>
        {{/each}}
        <dt>{{i18n "discourse_workflows.oauth2.last_refreshed"}}</dt>
        <dd><DRelativeDate @date={{@connection.last_refreshed_at}} /></dd>
      </dl>
    {{/if}}
  </div>
</template>;

export default OAuth2ConnectionDetails;
