import { popupAjaxError } from "discourse/lib/ajax-error";
import BufferedContent from "discourse/mixins/buffered-content";
import { propertyNotEqual } from "discourse/lib/computed";

export default Ember.Controller.extend(BufferedContent, {
  adminBadges: Ember.inject.controller(),
  saving: false,
  savingStatus: "",

  badgeTypes: Ember.computed.alias("adminBadges.badgeTypes"),
  badgeGroupings: Ember.computed.alias("adminBadges.badgeGroupings"),
  badgeTriggers: Ember.computed.alias("adminBadges.badgeTriggers"),
  protectedSystemFields: Ember.computed.alias(
    "adminBadges.protectedSystemFields"
  ),

  readOnly: Ember.computed.alias("buffered.system"),
  showDisplayName: propertyNotEqual("name", "displayName"),

  hasQuery: function() {
    const bQuery = this.get("buffered.query");
    if (bQuery) {
      return bQuery.trim().length > 0;
    }
    const mQuery = this.get("model.query");
    return mQuery && mQuery.trim().length > 0;
  }.property("model.query", "buffered.query"),

  _resetSaving: function() {
    this.set("saving", false);
    this.set("savingStatus", "");
  }.observes("model.id"),

  actions: {
    save() {
      if (!this.get("saving")) {
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
          var protectedFields = this.get("protectedSystemFields");
          fields = _.filter(fields, function(f) {
            return !_.include(protectedFields, f);
          });
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
        const buffered = this.get("buffered");
        fields.forEach(function(field) {
          var d = buffered.get(field);
          if (_.include(boolFields, field)) {
            d = !!d;
          }
          data[field] = d;
        });

        const newBadge = !this.get("id");
        const model = this.get("model");
        this.get("model")
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
      const model = this.get("model");

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
