import { ajax } from "discourse/lib/ajax";
import Badge from "discourse/models/badge";
import BadgeGrouping from "discourse/models/badge-grouping";

export default Discourse.Route.extend({
  _json: null,

  model() {
    return ajax("/admin/badges.json").then(json => {
      this._json = json;
      return Badge.createFromJson(json);
    });
  },

  setupController(controller, model) {
    const json = this._json;
    const badgeTriggers = [];
    const badgeGroupings = [];

    _.each(json.admin_badges.triggers, function(v, k) {
      badgeTriggers.push({
        id: v,
        name: I18n.t("admin.badges.trigger_type." + k)
      });
    });

    json.badge_groupings.forEach(function(badgeGroupingJson) {
      badgeGroupings.push(BadgeGrouping.create(badgeGroupingJson));
    });

    controller.setProperties({
      badgeGroupings: badgeGroupings,
      badgeTypes: json.badge_types,
      protectedSystemFields: json.admin_badges.protected_system_fields,
      badgeTriggers,
      model
    });
  }
});
