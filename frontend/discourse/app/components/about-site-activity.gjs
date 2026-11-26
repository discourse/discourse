import Component from "@glimmer/component";
import { service } from "@ember/service";
import { number } from "discourse/lib/formatter";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const pluginActivitiesFuncs = [];

export function addAboutPageActivity(name, func) {
  pluginActivitiesFuncs.push({ name, func });
}

export function clearAboutPageActivities() {
  pluginActivitiesFuncs.length = 0;
}

export default class AboutSiteActivity extends Component {
  @service siteSettings;

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
    {{#if @model.stats}}
      <h2>{{i18n "about.site_activity"}}</h2>
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
    {{/if}}
  </template>
}
