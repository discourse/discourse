import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

class DiscourseIdAdmin extends Component {
  @service dialog;
  @service toasts;

  @tracked isRegenerating = false;
  @tracked enabled;

  constructor() {
    super(...arguments);
    this.enabled = this.args.model.enabled;
  }

  get hasCustomProvider() {
    const url = this.args.model.provider_url;
    return url && url !== "https://id.discourse.com";
  }

  get regenerateDisabled() {
    return !this.args.model.configured || this.isRegenerating;
  }

  @action
  async regenerateCredentials() {
    this.dialog.confirm({
      message: i18n("admin.config.discourse_id.advanced.regenerate_confirm"),
      didConfirm: async () => {
        this.isRegenerating = true;
        try {
          await ajax(
            "/admin/config/login-and-authentication/discourse-id/regenerate",
            {
              type: "POST",
            }
          );
          this.toasts.success({
            data: {
              message: i18n(
                "admin.config.discourse_id.advanced.regenerate_success"
              ),
            },
            duration: 3000,
          });
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.isRegenerating = false;
        }
      },
    });
  }

  @action
  async toggleEnabled() {
    this.enabled = !this.enabled;
    try {
      await ajax(
        "/admin/config/login-and-authentication/discourse-id/settings",
        {
          type: "PUT",
          data: { enabled: this.enabled },
        }
      );
    } catch (error) {
      this.enabled = !this.enabled;
      popupAjaxError(error);
    }
  }

  <template>
    <div class="admin-config-area discourse-id-admin">
      <div class="admin-config-area__primary-content">
        {{! Status Card }}
        <section class="admin-config-area-card">
          <h3 class="admin-config-area-card__title">
            {{icon "circle-info"}}
            {{i18n "admin.config.discourse_id.status.title"}}
          </h3>
          <div class="admin-config-area-card__content">
            <div class="discourse-id-status">
              <div class="discourse-id-status__row">
                <span class="discourse-id-status__label">
                  {{i18n "admin.config.discourse_id.enabled"}}
                </span>
                <DToggleSwitch
                  @state={{this.enabled}}
                  {{on "click" this.toggleEnabled}}
                />
              </div>
              {{#if this.hasCustomProvider}}
                <div class="discourse-id-status__row">
                  <span class="discourse-id-status__label">
                    {{i18n "admin.config.discourse_id.provider"}}
                  </span>
                  <span class="discourse-id-status__value">
                    {{@model.provider_url}}
                  </span>
                </div>
              {{/if}}
              <div class="discourse-id-status__row">
                <span class="discourse-id-status__label">
                  {{i18n "admin.config.discourse_id.client_id"}}
                </span>
                <span class="discourse-id-status__value">
                  {{#if @model.client_id}}
                    <code>{{@model.client_id}}</code>
                  {{else}}
                    <span class="discourse-id-status__not-configured">
                      {{i18n "admin.config.discourse_id.not_configured"}}
                    </span>
                  {{/if}}
                </span>
              </div>
            </div>
          </div>
        </section>

        {{! Statistics Card }}
        <section class="admin-config-area-card">
          <h3 class="admin-config-area-card__title">
            {{icon "chart-bar"}}
            {{i18n "admin.config.discourse_id.stats.title"}}
          </h3>
          <div class="admin-config-area-card__content">
            <div class="discourse-id-stats">
              <div class="discourse-id-stats__item">
                <span class="discourse-id-stats__value">
                  {{@model.stats.total_users}}
                </span>
                <span class="discourse-id-stats__label">
                  {{i18n "admin.config.discourse_id.stats.total_users"}}
                </span>
              </div>
              <div class="discourse-id-stats__item">
                <span class="discourse-id-stats__value">
                  {{@model.stats.signups_30_days}}
                </span>
                <span class="discourse-id-stats__label">
                  {{i18n "admin.config.discourse_id.stats.signups_30_days"}}
                </span>
              </div>
              <div class="discourse-id-stats__item">
                <span class="discourse-id-stats__value">
                  {{@model.stats.logins_30_days}}
                </span>
                <span class="discourse-id-stats__label">
                  {{i18n "admin.config.discourse_id.stats.logins_30_days"}}
                </span>
              </div>
            </div>
          </div>
        </section>

        {{! Advanced Accordion }}
        <details class="admin-config-area-card discourse-id-advanced-accordion">
          <summary class="admin-config-area-card__title">
            {{i18n "admin.config.discourse_id.advanced.title"}}
          </summary>
          <div class="admin-config-area-card__content">
            <div class="discourse-id-advanced">
              {{! Regenerate Credentials }}
              <div
                class="discourse-id-advanced__row discourse-id-advanced__row--danger"
              >
                <div class="discourse-id-advanced__setting">
                  <span class="discourse-id-advanced__label">
                    {{i18n
                      "admin.config.discourse_id.advanced.regenerate_credentials"
                    }}
                  </span>
                  <span class="discourse-id-advanced__description">
                    {{i18n
                      "admin.config.discourse_id.advanced.regenerate_warning"
                    }}
                  </span>
                </div>
                <DButton
                  @action={{this.regenerateCredentials}}
                  @label="admin.config.discourse_id.advanced.regenerate_button"
                  @disabled={{this.regenerateDisabled}}
                  @isLoading={{this.isRegenerating}}
                  class="btn-danger"
                />
              </div>
            </div>
          </div>
        </details>
      </div>
    </div>
  </template>
}

export default <template><DiscourseIdAdmin @model={{@model}} /></template>
