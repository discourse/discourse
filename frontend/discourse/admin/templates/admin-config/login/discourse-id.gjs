import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
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

  get regenerateDisabled() {
    return !this.args.model.configured || this.isRegenerating;
  }

  @action
  async regenerateCredentials() {
    this.dialog.confirm({
      message: i18n("admin.config.discourse_id.regenerate_confirm"),
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
              message: i18n("admin.config.discourse_id.regenerate_success"),
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
        <section class="admin-config-area-card">
          <div class="discourse-id-header">
            <h3 class="admin-config-area-card__title">
              {{i18n "admin.config.discourse_id.title"}}
            </h3>
            <DToggleSwitch
              @state={{this.enabled}}
              {{on "click" this.toggleEnabled}}
            />
          </div>

          <p class="admin-config-area-card__description">
            {{i18n "admin.config.discourse_id.description"}}
            <a
              href="https://id.discourse.com"
              target="_blank"
              rel="noopener noreferrer"
            >{{i18n "admin.config.discourse_id.learn_more"}}</a>
          </p>

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

            <div class="discourse-id-footer">
              <DButton
                @action={{this.regenerateCredentials}}
                @label="admin.config.discourse_id.regenerate_credentials"
                @disabled={{this.regenerateDisabled}}
                @isLoading={{this.isRegenerating}}
                class="btn-default btn-small"
              />
            </div>
          </div>
        </section>
      </div>
    </div>
  </template>
}

export default <template><DiscourseIdAdmin @model={{@model}} /></template>
