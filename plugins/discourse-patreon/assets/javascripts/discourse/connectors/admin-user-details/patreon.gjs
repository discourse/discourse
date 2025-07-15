import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("admin-user-details-outlet", "patreon")
export default class Patreon extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.patreon_enabled && args.model.patreon_id;
  }

  init() {
    super.init(...arguments);
    this.set("patron_url", "https://patreon.com/members");
  }

  @action
  checkPatreonEmail(user) {
    ajax(userPath(`${user.username_lower}/patreon_email.json`), {
      data: {
        context: window.location.pathname,
      },
    }).then((result) => {
      if (result) {
        const email = result.email;
        let url = "https://patreon.com/members";
        if (email) {
          url = `${url}?query=${email}`;
        }
        this.set("patreon_email", email);
        this.set("patron_url", url);
      }
    });
  }

  <template>
    <section class="details">
      <h1>{{i18n "patreon.title"}}</h1>
      <div class="display-row">
        <div class="field">{{i18n "patreon.field.id"}}</div>
        <div class="value">{{this.model.patreon_id}}</div>
      </div>
      {{#if this.model.patreon_email_exists}}
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.email"}}</div>
          <div class="value">
            {{#if this.patreon_email}}
              {{this.patreon_email}}
            {{else}}
              <DButton
                {{! template-lint-disable no-action }}
                @action={{action "checkPatreonEmail" this.model}}
                @icon="far-envelope"
                @label="admin.users.check_email.text"
                @title="admin.users.check_email.title"
                class="btn-default"
              />
            {{/if}}
          </div>
        </div>
      {{/if}}
      {{#if this.model.patreon_amount_cents}}
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.amount_cents"}}</div>
          <div class="value">{{this.model.patreon_amount_cents}}</div>
        </div>
      {{/if}}
      {{#if this.model.patreon_rewards}}
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.rewards"}}</div>
          <div class="value">{{this.model.patreon_rewards}}</div>
        </div>
      {{/if}}
      {{#if this.model.patreon_declined_since}}
        <div class="display-row">
          <div class="field">{{i18n "patreon.field.declined_since"}}</div>
          <div class="value">{{htmlSafe
              this.format-date
              this.model.patreon_declined_since
            }}</div>
        </div>
      {{/if}}
      <div class="display-row">
        <div class="field">{{i18n "patreon.field.more_details.label"}}</div>
        <div class="value">
          <a rel="noopener noreferrer" target="_blank" href={{this.patron_url}}>
            {{icon "up-right-from-square"}}
          </a>
        </div>
        <div class="controls">
          {{#if this.model.patreon_email}}
            {{i18n "patreon.field.more_details.help_text.email_available"}}
          {{else}}
            {{i18n "patreon.field.more_details.help_text.email_not_available"}}
          {{/if}}
        </div>
      </div>
    </section>
  </template>
}
