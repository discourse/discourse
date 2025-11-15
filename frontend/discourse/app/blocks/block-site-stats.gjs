import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import { ajax } from "discourse/lib/ajax";

/*
 *   { source: "users", period: "count", title: "Total Users" }
 *   { source: "users", period: "last_day", title: "New Users Today" }
 *   { source: "users", period: "7_days", title: "New Users This Week" }
 *   { source: "users", period: "30_days", title: "New Users This Month" }
 *   { source: "topics", period: "count", title: "Total Topics" }
 *   { source: "topics", period: "last_day", title: "New Topics Today" }
 *   { source: "topics", period: "7_days", title: "New Topics This Week" }
 *   { source: "topics", period: "30_days", title: "New Topics This Month" }
 *   { source: "posts", period: "count", title: "Total Posts" }
 *   { source: "posts", period: "last_day", title: "New Posts Today" }
 *   { source: "posts", period: "7_days", title: "New Posts This Week" }
 *   { source: "posts", period: "30_days", title: "New Posts This Month" }
 *   { source: "likes", period: "count", title: "Total Likes" }
 *   { source: "likes", period: "last_day", title: "Likes Today" }
 *   { source: "likes", period: "7_days", title: "Likes This Week" }
 *   { source: "likes", period: "30_days", title: "Likes This Month" }
 *   { source: "sign_ups", period: "last_day", title: "Sign Ups Today" }
 *   { source: "sign_ups", period: "7_days", title: "Sign Ups This Week" }
 *   { source: "sign_ups", period: "30_days", title: "Sign Ups This Month" }
 *   { source: "active_users", period: "last_day", title: "Active Users Today" }
 *   { source: "active_users", period: "7_days", title: "Active Users This Week" }
 *   { source: "active_users", period: "30_days", title: "Active Users This Month" }
 */

@block("site-stats")
export default class BlockSiteStats extends Component {
  @tracked stats;

  <template>
    <div class="block-site-stats__layout" {{didInsert this.getAboutStats}}>
      {{#if @title}}
        <div class="block-site-stats__title">
          {{htmlSafe @title}}
        </div>
      {{/if}}
      <ul class="block-site-stats__list">
        {{#each this.filteredStats as |s|}}
          <li class="block-site-stats__item">
            {{#if s.link}}
              <a href={{s.link}}><span>{{s.value}}</span>
                <span>{{s.title}}</span></a>
            {{else}}
              <div>
                <span>{{s.value}}</span>
                <span>{{s.title}}</span>
              </div>
            {{/if}}
          </li>
        {{/each}}
      </ul>
    </div>
  </template>

  get filteredStats() {
    if (!this.stats) {
      return [];
    }

    const statConfig = this.args?.display_stats;

    if (!Array.isArray(statConfig)) {
      return [];
    }

    return statConfig
      .map((config) => {
        const keyName = `${config.source}_${config.period}`;
        const statValue = this.stats[keyName];

        if (statValue !== undefined) {
          return {
            title: config.title,
            value: config.manual_value || statValue,
            link: config.link,
            period: config.period,
          };
        }
      })
      .filter(Boolean);
  }

  saveToCache(key, value, expiryInMilliseconds) {
    if (!key || !value || !expiryInMilliseconds) {
      return;
    }

    const now = new Date();
    const item = {
      value,
      expiry: now.getTime() + expiryInMilliseconds,
    };

    try {
      localStorage.setItem(key, JSON.stringify(item));
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("Couldn't save to localStorage:", error);
    }
  }

  loadFromCache(key) {
    if (!key) {
      return null;
    }

    try {
      const itemStr = localStorage.getItem(key);

      if (!itemStr) {
        return null;
      }

      const item = JSON.parse(itemStr);
      const now = new Date();

      if (now.getTime() > item.expiry) {
        localStorage.removeItem(key);
        return null;
      }

      return item.value;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("Couldn't read from localStorage:", error);
      return null;
    }
  }

  cacheStats() {
    if (!this.stats || !this.filteredStats.length) {
      return;
    }

    const lowestPeriod = Math.min(
      ...this.filteredStats.map((stat) => this.parseDaysFromStat(stat.period))
    );

    const expiryInMilliseconds = lowestPeriod * 24 * 60 * 60 * 1000;
    this.saveToCache("about_stats", this.stats, expiryInMilliseconds);
    this.saveToCache(
      "banner_stats_setting",
      JSON.stringify(this.args?.display_stats),
      expiryInMilliseconds
    );
  }

  parseDaysFromStat(stat) {
    if (stat === "last_day") {
      return 1;
    }
    const parts = stat.split("_");
    return parseInt(parts[0], 10);
  }

  @action
  async getAboutStats() {
    let cachedStats = this.loadFromCache("about_stats");
    let cachedSetting = this.loadFromCache("banner_stats_setting");

    if (
      !this.args?.disable_cache &&
      cachedStats &&
      JSON.stringify(this.args?.display_stats) === cachedSetting
    ) {
      this.stats = cachedStats;
      return;
    }

    try {
      const result = await ajax("/about.json");
      this.stats = result.about.stats;
      if (this.args?.disable_cache) {
        localStorage.removeItem("about_stats");
        localStorage.removeItem("banner_stats_setting");
      } else {
        this.cacheStats();
      }
    } catch (error) {
      this.stats = null;
      // eslint-disable-next-line no-console
      console.error("BlockSiteStats failed to fetch data", error);
      throw error;
    }
  }
}
