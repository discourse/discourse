import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import AboutPageUsers from "discourse/components/about-page-users";
import PluginOutlet from "discourse/components/plugin-outlet";
import { number } from "discourse/lib/formatter";
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
      {
        class: "site-creation-date",
        icon: "calendar-alt",
        text: this.siteAgeString,
      },
    ];
  }

  get siteActivities() {
    return [
      {
        icon: "scroll",
        class: "topics",
        activityText: I18n.t("about.activities.topics", {
          count: this.args.model.stats.topics_7_days,
          formatted_number: number(this.args.model.stats.topics_7_days),
        }),
        period: I18n.t("about.activities.periods.last_7_days"),
      },
      {
        icon: "pencil-alt",
        class: "posts",
        activityText: I18n.t("about.activities.posts", {
          count: this.args.model.stats.posts_last_day,
          formatted_number: number(this.args.model.stats.posts_last_day),
        }),
        period: I18n.t("about.activities.periods.today"),
      },
      {
        icon: "user-friends",
        class: "active-users",
        activityText: I18n.t("about.activities.active_users", {
          count: this.args.model.stats.active_users_7_days,
          formatted_number: number(this.args.model.stats.active_users_7_days),
        }),
        period: I18n.t("about.activities.periods.last_7_days"),
      },
      {
        icon: "user-plus",
        class: "sign-ups",
        activityText: I18n.t("about.activities.sign_ups", {
          count: this.args.model.stats.users_7_days,
          formatted_number: number(this.args.model.stats.users_7_days),
        }),
        period: I18n.t("about.activities.periods.last_7_days"),
      },
      {
        icon: "heart",
        class: "likes",
        activityText: I18n.t("about.activities.likes", {
          count: this.args.model.stats.likes_count,
          formatted_number: number(this.args.model.stats.likes_count),
        }),
        period: I18n.t("about.activities.periods.all_time"),
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

  get siteAgeString() {
    const creationDate = new Date(this.args.model.site_creation_date);

    let diff = new Date() - creationDate;
    diff /= 1000 * 3600 * 24 * 30;

    if (diff < 1) {
      return I18n.t("about.site_age.less_than_one_month");
    } else if (diff < 12) {
      return I18n.t("about.site_age.month", { count: Math.round(diff) });
    } else {
      diff /= 12;
      return I18n.t("about.site_age.year", { count: Math.round(diff) });
    }
  }

  <template>
    <section class="about__header">
      {{#if @model.banner_image}}
        <img class="about__banner" src={{@model.banner_image}} />
      {{/if}}
      <h3>{{@model.title}}</h3>
      <p class="short-description">{{@model.description}}</p>
      <PluginOutlet
        @name="about-after-description"
        @connectorTagName="section"
        @outletArgs={{hash model=this.model}}
      />
    </section>
    <div class="about__main-content">
      <div class="about__left-side">
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

        {{#if @model.admins.length}}
          <section class="about__admins">
            <h3>{{dIcon "users"}} {{i18n "about.our_admins"}}</h3>
            <AboutPageUsers @users={{@model.admins}} @truncateAt={{12}} />
          </section>
        {{/if}}

        {{#if @model.moderators.length}}
          <section class="about__moderators">
            <h3>{{dIcon "users"}} {{i18n "about.our_moderators"}}</h3>
            <AboutPageUsers @users={{@model.moderators}} @truncateAt={{12}} />
          </section>
        {{/if}}
      </div>
      <div class="about__right-side">
        <h3>{{i18n "about.contact"}}</h3>
        {{#if this.contactInfo}}
          <p>{{htmlSafe this.contactInfo}}</p>
        {{/if}}
        <p>{{i18n "about.report_inappropriate_content"}}</p>
        <h3>{{i18n "about.site_activity"}}</h3>
        <div class="about__activities">
          {{#each this.siteActivities as |activity|}}
            <div class="about__activities-item {{activity.class}}">
              <span class="about__activities-item-icon">{{dIcon
                  activity.icon
                }}</span>
              <span class="about__activities-item-type">
                <div
                  class="about__activities-item-count"
                >{{activity.activityText}}</div>
                <div
                  class="about__activities-item-period"
                >{{activity.period}}</div>
              </span>
            </div>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
