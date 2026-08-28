import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

function authorizationStatus(status) {
  return i18n(`user.mcp_authorizations.statuses.${status}`);
}

class UserMcpAuthorizationRow extends Component {
  @tracked showPermissions = false;

  get hasPermissions() {
    return this.args.authorization.scopes?.length > 0;
  }

  get isReauthorizationRequired() {
    return this.args.authorization.status === "consent_required";
  }

  get canRevoke() {
    return this.args.authorization.status !== "revoked";
  }

  @action
  togglePermissions() {
    this.showPermissions = !this.showPermissions;
  }

  <template>
    <tr class="d-table__row user-mcp-authorization" ...attributes>
      <td class="d-table__cell --overview user-mcp-authorization__application">
        <div class="d-table__overview-name">{{@authorization.client_name}}</div>
      </td>
      <td class="d-table__cell --detail user-mcp-authorization__details-cell">
        <div class="d-table__mobile-label">{{i18n
            "user.mcp_authorizations.details"
          }}</div>
        <div class="user-mcp-authorization__details">
          <div class="user-mcp-authorization__authorized">
            <span>{{i18n "user.mcp_authorizations.authorized"}}:</span>
            {{dAgeWithTooltip @authorization.consented_at format="medium"}}
          </div>
          <div class="user-mcp-authorization__last-used">
            <span>{{i18n "user.mcp_authorizations.last_used"}}:</span>
            {{#if @authorization.last_used_at}}
              {{dAgeWithTooltip @authorization.last_used_at format="medium"}}
            {{else}}
              {{i18n "user.mcp_authorizations.never"}}
            {{/if}}
          </div>
          <span class="user-mcp-authorization__token-count">{{i18n
              "user.mcp_authorizations.active_tokens"
              count=@authorization.token_count
            }}</span>

          {{#if this.hasPermissions}}
            <div class="user-mcp-authorization__permissions">
              <DButton
                @action={{this.togglePermissions}}
                @icon={{if this.showPermissions "caret-up" "caret-down"}}
                @translatedLabel={{i18n
                  "user.mcp_authorizations.permissions"
                  count=@authorization.scopes.length
                }}
                @display="link"
                class="user-mcp-authorization__permissions-toggle"
                aria-expanded={{if this.showPermissions "true" "false"}}
              />
            </div>

            {{#if this.showPermissions}}
              <ul class="user-mcp-authorization__permissions-list">
                {{#each @authorization.scopes as |scope|}}
                  <li><code>{{scope}}</code></li>
                {{/each}}
              </ul>
            {{/if}}
          {{/if}}
        </div>
      </td>
      <td class="d-table__cell --detail user-mcp-authorization__status-cell">
        <div class="d-table__mobile-label">{{i18n
            "user.mcp_authorizations.status"
          }}</div>
        <div class="user-mcp-authorization__status-details">
          <span
            class="user-mcp-authorization__status"
            data-state={{@authorization.status}}
          >{{authorizationStatus @authorization.status}}</span>
          {{#if this.canRevoke}}
            <DButton
              @action={{@onRevoke}}
              @label="user.mcp_authorizations.revoke"
              class="btn-default btn-small"
            />
          {{/if}}
          {{#if this.isReauthorizationRequired}}
            <DButton
              @action={{@onReauthorize}}
              @label="user.mcp_authorizations.reauthorize"
              class="btn-default btn-small"
            />
          {{/if}}
        </div>
      </td>
    </tr>
  </template>
}

export default class UserMcpAuthorizations extends Component {
  @service a11y;
  @service currentUser;
  @service dialog;
  @service toasts;

  @tracked authorizations = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    if (!this.shouldRender) {
      this.loading = false;
      return;
    }
    this.#loadAuthorizations();
  }

  get shouldRender() {
    return (
      this.args.model?.id === this.currentUser?.id &&
      this.args.model?.show_mcp_authorizations
    );
  }

  get username() {
    return this.args.model?.username;
  }

  get endpoint() {
    return `/u/${encodeURIComponent(this.username)}/preferences/mcp-authorizations`;
  }

  get hasAuthorizations() {
    return this.authorizations.length > 0;
  }

  async #loadAuthorizations() {
    if (!this.username) {
      this.loading = false;
      return;
    }

    try {
      const result = await ajax(`${this.endpoint}.json`);
      this.authorizations = result.authorizations || result;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  revoke(authorization) {
    this.dialog.confirm({
      message: i18n("user.mcp_authorizations.revoke_confirm", {
        name: authorization.client_name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.endpoint}/${authorization.id}.json`, {
            type: "DELETE",
          });
          this.authorizations = this.authorizations.map((item) =>
            item.id === authorization.id
              ? { ...item, status: "revoked", token_count: 0 }
              : item
          );
          this.a11y.announce(i18n("user.mcp_authorizations.revoked"));
          this.toasts.success({
            duration: "short",
            data: { message: i18n("user.mcp_authorizations.revoked") },
          });
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  reauthorize() {
    this.dialog.alert({
      message: i18n("user.mcp_authorizations.reauthorize_in_client"),
    });
  }

  <template>
    {{#if this.shouldRender}}
      <div class="control-group user-mcp-authorizations">
        <label class="control-label">{{i18n
            "user.mcp_authorizations.title"
          }}</label>
        <p class="instructions">{{i18n
            "user.mcp_authorizations.description"
          }}</p>

        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.hasAuthorizations}}
            <table class="d-table user-mcp-authorizations__table">
              <colgroup>
                <col class="user-mcp-authorizations__application-column" />
                <col />
                <col class="user-mcp-authorizations__status-column" />
              </colgroup>
              <thead class="d-table__header">
                <tr class="d-table__row">
                  <th class="d-table__header-cell">{{i18n
                      "user.mcp_authorizations.application"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "user.mcp_authorizations.details"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "user.mcp_authorizations.status"
                    }}</th>
                </tr>
              </thead>
              <tbody class="d-table__body">
                {{#each this.authorizations as |authorization|}}
                  <UserMcpAuthorizationRow
                    @authorization={{authorization}}
                    @onRevoke={{fn this.revoke authorization}}
                    @onReauthorize={{this.reauthorize}}
                  />
                {{/each}}
              </tbody>
            </table>
          {{else}}
            <p class="user-mcp-authorizations__empty">{{i18n
                "user.mcp_authorizations.empty"
              }}</p>
          {{/if}}
        </DConditionalLoadingSpinner>
      </div>
    {{/if}}
  </template>
}
