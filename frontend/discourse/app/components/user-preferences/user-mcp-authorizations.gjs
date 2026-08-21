import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

function scopesValue(scopes) {
  return Array.isArray(scopes) ? scopes.join(", ") : scopes || "";
}

export default class UserMcpAuthorizations extends Component {
  @service a11y;
  @service dialog;
  @service siteSettings;
  @service toasts;

  @tracked authorizations = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    if (!this.siteSettings.mcp_server_enabled) {
      this.loading = false;
      return;
    }
    this.#loadAuthorizations();
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

  isReauthorizationRequired(authorization) {
    return authorization.status === "consent_required";
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
          this.authorizations = this.authorizations.filter(
            (item) => item.id !== authorization.id
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
    {{#if this.siteSettings.mcp_server_enabled}}
      <section
        class="user-mcp-authorizations"
        aria-labelledby="user-mcp-authorizations-title"
      >
        <h2 id="user-mcp-authorizations-title">{{i18n
            "user.mcp_authorizations.title"
          }}</h2>
        <p class="instructions">{{i18n
            "user.mcp_authorizations.description"
          }}</p>

        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.hasAuthorizations}}
            <div class="user-mcp-authorizations__list">
              {{#each this.authorizations as |authorization|}}
                <article class="user-mcp-authorization">
                  <div class="user-mcp-authorization__info">
                    <h3>{{authorization.client_name}}</h3>
                    <dl class="user-mcp-authorization__details">
                      <div><dt>{{i18n
                            "user.mcp_authorizations.endpoint"
                          }}</dt><dd>{{authorization.resource}}</dd></div>
                      <div><dt>{{i18n "user.mcp_authorizations.scopes"}}</dt><dd
                        >{{scopesValue authorization.scopes}}</dd></div>
                      <div><dt>{{i18n
                            "user.mcp_authorizations.authorized"
                          }}</dt><dd>{{dAgeWithTooltip
                            authorization.consented_at
                            format="medium"
                          }}</dd></div>
                      <div><dt>{{i18n
                            "user.mcp_authorizations.last_used"
                          }}</dt><dd>{{#if
                            authorization.last_used_at
                          }}{{dAgeWithTooltip
                              authorization.last_used_at
                              format="medium"
                            }}{{else}}{{i18n
                              "user.mcp_authorizations.never"
                            }}{{/if}}</dd></div>
                      <div><dt>{{i18n "user.mcp_authorizations.tokens"}}</dt><dd
                        >{{authorization.token_count}}</dd></div>
                    </dl>
                    <p class="user-mcp-authorization__status">{{i18n
                        "user.mcp_authorizations.status"
                      }}:
                      {{authorization.status}}</p>
                  </div>
                  <div class="user-mcp-authorization__actions">
                    {{#if (eq authorization.status "active")}}
                      <DButton
                        @action={{fn this.revoke authorization}}
                        @label="user.mcp_authorizations.revoke"
                        class="btn-danger btn-small"
                      />
                    {{else if (this.isReauthorizationRequired authorization)}}
                      <DButton
                        @action={{fn this.reauthorize authorization}}
                        @label="user.mcp_authorizations.reauthorize"
                        class="btn-default btn-small"
                      />
                    {{/if}}
                  </div>
                </article>
              {{/each}}
            </div>
          {{else}}
            <p class="user-mcp-authorizations__empty">{{i18n
                "user.mcp_authorizations.empty"
              }}</p>
          {{/if}}
        </DConditionalLoadingSpinner>
      </section>
    {{/if}}
  </template>
}
