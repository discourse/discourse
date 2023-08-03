import Badge from "discourse/models/badge";
import I18n from "I18n";
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { action, get } from "@ember/object";
import { inject as service } from "@ember/service";
import EditBadgeGroupingsModal from "../../components/modal/edit-badge-groupings";
import BadgePreviewModal from "../../components/modal/badge-preview";

export default class AdminBadgesShowRoute extends Route {
  @service dialog;
  @service modal;

  serialize(m) {
    return { badge_id: get(m, "id") || "new" };
  }

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: I18n.t("admin.badges.new_badge"),
      });
    }
    return this.modelFor("adminBadges").findBy(
      "id",
      parseInt(params.badge_id, 10)
    );
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    if (model.image_url) {
      controller.showImageUploader();
    } else if (model.icon) {
      controller.showIconSelector();
    }
  }

  @action
  editGroupings() {
    const model = this.controllerFor("admin-badges").get("badgeGroupings");
    this.modal.show(EditBadgeGroupingsModal, {
      model: {
        badgeGroupings: model,
        updateGroupings: this.updateGroupings,
      },
    });
  }

  @action
  updateGroupings(groupings) {
    this.controllerFor("admin-badges").set("badgeGroupings", groupings);
  }

  @action
  async preview(badge, explain) {
    try {
      badge.set("preview_loading", true);
      const model = await ajax("/admin/badges/preview.json", {
        type: "POST",
        data: {
          sql: badge.get("query"),
          target_posts: !!badge.get("target_posts"),
          trigger: badge.get("trigger"),
          explain,
        },
      });
      badge.set("preview_loading", false);
      this.modal.show(BadgePreviewModal, { model: { badge: model } });
    } catch (e) {
      badge.set("preview_loading", false);
      // eslint-disable-next-line no-console
      console.error(e);
      this.dialog.alert("Network error");
    }
  }
}
