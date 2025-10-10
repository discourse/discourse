import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Badge from "discourse/models/badge";
import BadgeGrouping from "discourse/models/badge-grouping";
import { i18n } from "discourse-i18n";

export default class AdminBadges extends Service {
  @tracked data;
  @tracked badges;
  @tracked badgeGroupings = [];

  get badgeTypes() {
    if (!this.data) {
      return [];
    }

    return this.data.badge_types;
  }

  get badgeTriggers() {
    if (!this.data) {
      return [];
    }

    return Object.keys(this.data.admin_badges.triggers).map((key) => {
      return {
        id: this.data.admin_badges.triggers[key],
        name: i18n("admin.badges.trigger_type." + key),
      };
    });
  }

  get protectedSystemFields() {
    if (!this.data) {
      return [];
    }

    return this.data.admin_badges.protected_system_fields;
  }

  async fetchBadges() {
    if (!this.badges) {
      try {
        this.data = await ajax("/admin/badges.json");
        this.badges = Badge.createFromJson(this.data);
        this.badgeGroupings = this.#groupBadges(this.data);
      } catch (err) {
        popupAjaxError(err);
      }
    }
  }

  #groupBadges(data) {
    return data.badge_groupings.map((badgeGroupingJson) => {
      return BadgeGrouping.create(badgeGroupingJson);
    });
  }
}
