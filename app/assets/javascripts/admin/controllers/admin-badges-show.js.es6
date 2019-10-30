import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import { propertyNotEqual } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(bufferedProperty("model"), {
  adminBadges: inject(),
  saving: false,
  savingStatus: "",

  badgeTypes: alias("adminBadges.badgeTypes"),
  badgeGroupings: alias("adminBadges.badgeGroupings"),
  badgeTriggers: alias("adminBadges.badgeTriggers"),
  protectedSystemFields: alias(
    "adminBadges.protectedSystemFields"
  ),

  readOnly: alias("buffered.system"),
  showDisplayName: propertyNotEqual("name", "displayName"),

  @computed("model.query", "buffered.query")
  hasQuery(modelQuery, bufferedQuery) {
    if (bufferedQuery) {
      return bufferedQuery.trim().length > 0;
    }
    return modelQuery && modelQuery.trim().length > 0;
  },

  _resetSaving: function() {
    this.set("saving", false);
    this.set("savingStatus", "");
  }.observes("model.id"),

  actions: {
    save() {
      if (!this.saving) {
        let fields = [
          "allow_title",
          "multiple_grant",
          "listable",
          "auto_revoke",
          "enabled",
          "show_posts",
          "target_posts",
          "name",
          "description",
          "long_description",
          "icon",
          "image",
          "query",
          "badge_grouping_id",
          "trigger",
          "badge_type_id"
        ];

        if (this.get("buffered.system")) {
          var protectedFields = this.protectedSystemFields || [];
          fields = _.filter(fields, f => !protectedFields.includes(f));
        }

        this.set("saving", true);
        this.set("savingStatus", I18n.t("saving"));

        const boolFields = [
          "allow_title",
          "multiple_grant",
          "listable",
          "auto_revoke",
          "enabled",
          "show_posts",
          "target_posts"
        ];

        const data = {};
        const buffered = this.buffered;
        fields.forEach(function(field) {
          var d = buffered.get(field);
          if (boolFields.includes(field)) {
            d = !!d;
          }
          data[field] = d;
        });

        const newBadge = !this.id;
        const model = this.model;
        this.model
          .save(data)
          .then(() => {
            if (newBadge) {
              const adminBadges = this.get("adminBadges.model");
              if (!adminBadges.includes(model)) {
                adminBadges.pushObject(model);
              }
              this.transitionToRoute("adminBadges.show", model.get("id"));
            } else {
              this.commitBuffer();
              this.set("savingStatus", I18n.t("saved"));
            }
          })
          .catch(popupAjaxError)
          .finally(() => {
            this.set("saving", false);
            this.set("savingStatus", "");
          });
      }
    },

    destroy() {
      const adminBadges = this.get("adminBadges.model");
      const model = this.model;

      if (!model.get("id")) {
        this.transitionToRoute("adminBadges.index");
        return;
      }

      return bootbox.confirm(
        I18n.t("admin.badges.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            model
              .destroy()
              .then(() => {
                adminBadges.removeObject(model);
                this.transitionToRoute("adminBadges.index");
              })
              .catch(() => {
                bootbox.alert(I18n.t("generic_error"));
              });
          }
        }
      );
    }
  }
});
