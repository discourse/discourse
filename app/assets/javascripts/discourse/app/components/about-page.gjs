import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import escape from "discourse-common/lib/escape";
import I18n from "discourse-i18n";

export default class AboutPage extends Component {
  get moderatorsCount() {
    return this.args.model.moderators.length;
  }

  get adminsCount() {
    return this.args.model.admins.length;
  }

  get stats() {
    return [
      {
        class: "members",
        icon: "users",
        text: I18n.t("about.member_count", {
          count: this.args.model.stats.users_count,
          formatted_number: I18n.toNumber(this.args.model.stats.users_count, {
            precision: 0,
          }),
        }),
      },
      {
        class: "admins",
        icon: "shield-alt",
        text: I18n.t("about.admin_count", {
          count: this.adminsCount,
          formatted_number: I18n.toNumber(this.adminsCount, { precision: 0 }),
        }),
      },
      {
        class: "moderators",
        icon: "shield-alt",
        text: I18n.t("about.moderator_count", {
          count: this.moderatorsCount,
          formatted_number: I18n.toNumber(this.moderatorsCount, {
            precision: 0,
          }),
        }),
      },
    ];
  }

  get contactInfo() {
    const url = escape(this.args.model.contact_url || "");
    const email = escape(this.args.model.contact_email || "");

    if (url) {
      return I18n.t("about.contact_info", {
        contact_info: `<a href='${url}' target='_blank'>${url}</a>`,
      });
    } else if (email) {
      return I18n.t("about.contact_info", {
        contact_info: `<a href="mailto:${email}">${email}</a>`,
      });
    } else {
      return null;
    }
  }

  <template>
    <section class="about__header">
      <img class="about__banner" src={{@model.banner_image}} />
      <h3>{{@model.title}}</h3>
      <p class="short-description">{{@model.description}}</p>
      <PluginOutlet
        @name="about-after-description"
        @connectorTagName="section"
        @outletArgs={{hash model=this.model}}
      />
    </section>
    <div class="about__main-content">
      <section class="about__left-side">
        <div class="about__stats">
          {{#each this.stats as |stat|}}
            <span class="about__stats-item {{stat.class}}">
              {{dIcon stat.icon}}
              <span>{{stat.text}}</span>
            </span>
          {{/each}}
        </div>
        <h3>{{i18n "about.simple_title"}}</h3>
        <div>{{htmlSafe @model.extended_site_description}}</div>
      </section>
      <section class="about__right-side">
        <h4>{{i18n "about.contact"}}</h4>
        {{#if this.contactInfo}}
          <p>{{htmlSafe this.contactInfo}}</p>
        {{/if}}
        <p>{{i18n "about.report_inappropriate_content"}}</p>
      </section>
    </div>
  </template>
}
