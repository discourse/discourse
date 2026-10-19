import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Patreon extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.patreon_enabled && args.model.patreon_id;
  }

  @tracked patreon_email;
  @tracked patron_url = "https://patreon.com/members";

  @action
  async checkPatreonEmail() {
    const result = await ajax(
      userPath(`${this.args.model.username_lower}/patreon_email.json`),
      {
        data: {
          context: window.location.pathname,
        },
      }
    );

    if (result) {
      const email = result.email;

      let url = "https://patreon.com/members";
      if (email) {
        url = `${url}?query=${email}`;
      }

      this.patreon_email = email;
      this.patron_url = url;
    }
  }

  <template>
    <div class="admin-user-details-outlet patreon" ...attributes>
      <section class="details">
        <h1>{{i18n "patreon.title"}}</h1>
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.id"}}</div>
          <div class="value">{{@model.patreon_id}}</div>
        </div>
        {{#if @model.patreon_email_exists}}
          <div class="display-row">
            <div class="field">{{i18n "patreon.field.email"}}</div>
            <div class="value">
              {{#if this.patreon_email}}
                {{this.patreon_email}}
              {{else}}
                <DButton
                  class="btn-default"
                  @action={{this.checkPatreonEmail}}
                  @icon="far-envelope"
                  @label="admin.users.check_email.text"
                  @title="admin.users.check_email.title"
                />
              {{/if}}
            </div>
          </div>
        {{/if}}
        {{#if @model.patreon_amount_cents}}
          <div class="display-row">
            <div class="field">{{i18n "patreon.field.amount_cents"}}</div>
            <div class="value">{{@model.patreon_amount_cents}}</div>
          </div>
        {{/if}}
        {{#if @model.patreon_rewards}}
          <div class="display-row">
            <div class="field">{{i18n "patreon.field.rewards"}}</div>
            <div class="value">{{@model.patreon_rewards}}</div>
          </div>
        {{/if}}
        {{#if @model.patreon_declined_since}}
          <div class="display-row">
            <div class="field">{{i18n "patreon.field.declined_since"}}</div>
            <div class="value">{{dFormatDate
                @model.patreon_declined_since
              }}</div>
          </div>
        {{/if}}
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.more_details.label"}}</div>
          <div class="value">
            <a
              href={{this.patron_url}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{dIcon "up-right-from-square"}}
            </a>
          </div>
          <div class="controls">
            {{#if @model.patreon_email}}
              {{i18n "patreon.field.more_details.help_text.email_available"}}
            {{else}}
              {{i18n
                "patreon.field.more_details.help_text.email_not_available"
              }}
            {{/if}}
          </div>
        </div>
      </section>
    </div>
  </template>
}
