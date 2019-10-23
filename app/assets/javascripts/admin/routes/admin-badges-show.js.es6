import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import Badge from "discourse/models/badge";
import showModal from "discourse/lib/show-modal";

export default Route.extend({
  serialize(m) {
    return { badge_id: Ember.get(m, "id") || "new" };
  },

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: I18n.t("admin.badges.new_badge")
      });
    }
    return this.modelFor("adminBadges").findBy("id", parseInt(params.badge_id));
  },

  actions: {
    saveError(e) {
      let msg = I18n.t("generic_error");
      if (e.responseJSON && e.responseJSON.errors) {
        msg = I18n.t("generic_error_with_reason", {
          error: e.responseJSON.errors.join(". ")
        });
      }
      bootbox.alert(msg);
    },

    editGroupings() {
      const model = this.controllerFor("admin-badges").get("badgeGroupings");
      showModal("admin-edit-badge-groupings", { model, admin: true });
    },

    preview(badge, explain) {
      badge.set("preview_loading", true);
      ajax("/admin/badges/preview.json", {
        method: "post",
        data: {
          sql: badge.get("query"),
          target_posts: !!badge.get("target_posts"),
          trigger: badge.get("trigger"),
          explain
        }
      })
        .then(function(model) {
          badge.set("preview_loading", false);
          showModal("admin-badge-preview", { model, admin: true });
        })
        .catch(function(error) {
          badge.set("preview_loading", false);
          Ember.Logger.error(error);
          bootbox.alert("Network error");
        });
    }
  }
});
