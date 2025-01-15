import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import AboutPageUsers from "discourse/components/about-page-users";
import PluginOutlet from "discourse/components/plugin-outlet";
import dIcon from "discourse/helpers/d-icon";
import escape from "discourse/lib/escape";
import { number } from "discourse/lib/formatter";
import I18n, { i18n } from "discourse-i18n";

const pluginActivitiesFuncs = [];

export function addAboutPageActivity(name, func) {
  pluginActivitiesFuncs.push({ name, func });
}

export function clearAboutPageActivities() {
  pluginActivitiesFuncs.clear();
}

export default class AboutPage extends Component {
  @service siteSettings;
  @service currentUser;

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
        text: i18n("about.member_count", {
          count: this.args.model.stats.users_count,
          formatted_number: I18n.toNumber(this.args.model.stats.users_count, {
            precision: 0,
          }),
        }),
      },
      {
        class: "admins",
        icon: "shield-halved",
        text: i18n("about.admin_count", {
          count: this.adminsCount,
          formatted_number: I18n.toNumber(this.adminsCount, { precision: 0 }),
        }),
      },
      {
        class: "moderators",
        icon: "shield-halved",
        text: i18n("about.moderator_count", {
          count: this.moderatorsCount,
          formatted_number: I18n.toNumber(this.moderatorsCount, {
            precision: 0,
          }),
        }),
      },
      {
        class: "site-creation-date",
        icon: "calendar-days",
        text: this.siteAgeString,
      },
    ];
  }

  get siteActivities() {
    const list = [
      {
        icon: "scroll",
        class: "topics",
        activityText: i18n("about.activities.topics", {
          count: this.args.model.stats.topics_7_days,
          formatted_number: number(this.args.model.stats.topics_7_days),
        }),
        period: i18n("about.activities.periods.last_7_days"),
      },
      {
        icon: "pencil",
        class: "posts",
        activityText: i18n("about.activities.posts", {
          count: this.args.model.stats.posts_last_day,
          formatted_number: number(this.args.model.stats.posts_last_day),
        }),
        period: i18n("about.activities.periods.today"),
      },
      {
        icon: "user-group",
        class: "active-users",
        activityText: i18n("about.activities.active_users", {
          count: this.args.model.stats.active_users_7_days,
          formatted_number: number(this.args.model.stats.active_users_7_days),
        }),
        period: i18n("about.activities.periods.last_7_days"),
      },
      {
        icon: "user-plus",
        class: "sign-ups",
        activityText: i18n("about.activities.sign_ups", {
          count: this.args.model.stats.users_7_days,
          formatted_number: number(this.args.model.stats.users_7_days),
        }),
        period: i18n("about.activities.periods.last_7_days"),
      },
      {
        icon: "heart",
        class: "likes",
        activityText: i18n("about.activities.likes", {
          count: this.args.model.stats.likes_count,
          formatted_number: number(this.args.model.stats.likes_count),
        }),
        period: i18n("about.activities.periods.all_time"),
      },
    ];

    if (this.displayVisitorStats) {
      list.splice(2, 0, {
        icon: "user-secret",
        class: "visitors",
        activityText: I18n.messageFormat("about.activities.visitors_MF", {
          total_count: this.args.model.stats.visitors_7_days,
          eu_count: this.args.model.stats.eu_visitors_7_days,
          total_formatted_number: number(this.args.model.stats.visitors_7_days),
          eu_formatted_number: number(this.args.model.stats.eu_visitors_7_days),
        }),
        period: i18n("about.activities.periods.last_7_days"),
      });
    }

    return list.concat(this.siteActivitiesFromPlugins());
  }

  get displayVisitorStats() {
    return (
      this.siteSettings.display_eu_visitor_stats &&
      typeof this.args.model.stats.eu_visitors_7_days === "number" &&
      typeof this.args.model.stats.visitors_7_days === "number"
    );
  }

  get contactInfo() {
    const url = escape(this.args.model.contact_url || "");
    const email = escape(this.args.model.contact_email || "");

    if (url) {
      const href = this.contactURLHref;
      return i18n("about.contact_info", {
        contact_info: `<a href='${href}' target='_blank'>${url}</a>`,
      });
    } else if (email) {
      return i18n("about.contact_info", {
        contact_info: `<a href="mailto:${email}">${email}</a>`,
      });
    } else {
      return null;
    }
  }

  get contactURLHref() {
    const url = escape(this.args.model.contact_url || "");

    if (!url) {
      return;
    }

    if (url.startsWith("/") || url.match(/^\w+:/)) {
      return url;
    }

    return `//${url}`;
  }

  get siteAgeString() {
    const creationDate = new Date(this.args.model.site_creation_date);

    let diff = new Date() - creationDate;
    diff /= 1000 * 3600 * 24 * 30;

    if (diff < 1) {
      return i18n("about.site_age.less_than_one_month");
    } else if (diff < 12) {
      return i18n("about.site_age.month", { count: Math.round(diff) });
    } else {
      diff /= 12;
      return i18n("about.site_age.year", { count: Math.round(diff) });
    }
  }

  get trafficInfoFooter() {
    return I18n.messageFormat("about.traffic_info_footer_MF", {
      total_visitors: this.args.model.stats.visitors_30_days,
      eu_visitors: this.args.model.stats.eu_visitors_30_days,
    });
  }

  siteActivitiesFromPlugins() {
    const stats = this.args.model.stats;
    const statKeys = Object.keys(stats);

    const configs = [];
    for (const { name, func } of pluginActivitiesFuncs) {
      let present = false;
      const periods = {};
      for (const stat of statKeys) {
        const prefix = `${name}_`;
        if (stat.startsWith(prefix)) {
          present = true;
          const period = stat.replace(prefix, "");
          periods[period] = stats[stat];
        }
      }
      if (!present) {
        continue;
      }
      const config = func(periods);
      if (config) {
        configs.push(config);
      }
    }
    return configs;
  }

  <template>
    {{#if this.currentUser.admin}}
      <p>
        <LinkTo class="edit-about-page" @route="adminConfig.about">
          {{dIcon "pencil"}}
          <span>{{i18n "about.edit"}}</span>
        </LinkTo>
      </p>
    {{/if}}
    <section class="about__header">
      {{#if @model.banner_image}}
        <div class="about__banner">
          <img class="about__banner-img" src={{@model.banner_image}} />
        </div>
      {{/if}}
      <h3>{{@model.title}}</h3>
      <p class="short-description">{{@model.description}}</p>
      <PluginOutlet
        @name="about-after-description"
        @connectorTagName="section"
        @outletArgs={{hash model=@model}}
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

        {{#if @model.extended_site_description}}
          <h3>{{i18n "about.simple_title"}}</h3>
          <div>{{htmlSafe @model.extended_site_description}}</div>
        {{/if}}

        {{#if @model.admins.length}}
          <section class="about__admins">
            <h3>{{i18n "about.our_admins"}}</h3>
            <AboutPageUsers @users={{@model.admins}} @truncateAt={{6}} />
          </section>
        {{/if}}
        <PluginOutlet
          @name="about-after-admins"
          @connectorTagName="section"
          @outletArgs={{hash model=@model}}
        />

        {{#if @model.moderators.length}}
          <section class="about__moderators">
            <h3>{{i18n "about.our_moderators"}}</h3>
            <AboutPageUsers @users={{@model.moderators}} @truncateAt={{6}} />
          </section>
        {{/if}}
        <PluginOutlet
          @name="about-after-moderators"
          @connectorTagName="section"
          @outletArgs={{hash model=@model}}
        />
      </div>

      <div class="about__right-side">
        <h3>{{i18n "about.contact"}}</h3>
        {{#if this.contactInfo}}
          <p class="about__contact-info">{{htmlSafe this.contactInfo}}</p>
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
        {{#if this.displayVisitorStats}}
          <p class="about traffic-info-footer"><small
            >{{this.trafficInfoFooter}}</small></p>
        {{/if}}
      </div>
    </div>
  </template>
}
