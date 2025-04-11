import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Badge from "discourse/models/badge";
import BadgeGrouping from "discourse/models/badge-grouping";

export default class AdminBadges extends Service {
  @tracked badges = [];

  @tracked badgeGroupings = [];

  constructor() {
    super(...arguments);

    this.#fetchBadges();
  }

  async #fetchBadges() {
    try {
      const data = await ajax("/admin/badges.json");
      this.badgeGroupings = data.badge_groupings.map((badgeGroupingJson) => {
        return BadgeGrouping.create(badgeGroupingJson);
      });
      this.badges = Badge.createFromJson(data);
    } catch (err) {
      popupAjaxError(err);
    }
  }
}
