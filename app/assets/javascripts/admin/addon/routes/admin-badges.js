import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Badge from "discourse/models/badge";
import BadgeGrouping from "discourse/models/badge-grouping";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";
import EditBadgeGroupingsModal from "../components/modal/edit-badge-groupings";

export default class AdminBadgesRoute extends DiscourseRoute {
  @service modal;

  _json = null;

  async model() {
    let json = await ajax("/admin/badges.json");
    this._json = json;
    return Badge.createFromJson(json);
  }

  @action
  editGroupings() {
    const model = this.controllerFor("admin-badges").badgeGroupings;
    this.modal.show(EditBadgeGroupingsModal, {
      model: {
        badgeGroupings: model,
        updateGroupings: this.updateGroupings,
      },
    });
  }

  setupController(controller, model) {
    const json = this._json;
    const badgeTriggers = [];
    const badgeGroupings = [];

    Object.keys(json.admin_badges.triggers).forEach((k) => {
      const id = json.admin_badges.triggers[k];
      badgeTriggers.push({
        id,
        name: I18n.t("admin.badges.trigger_type." + k),
      });
    });

    json.badge_groupings.forEach(function (badgeGroupingJson) {
      badgeGroupings.push(BadgeGrouping.create(badgeGroupingJson));
    });

    controller.badgeGroupings = badgeGroupings;
    controller.badgeTypes = json.badge_types;
    controller.protectedSystemFields =
      json.admin_badges.protected_system_fields;
    controller.badgeTriggers = badgeTriggers;
    controller.model = model;
  }
}
