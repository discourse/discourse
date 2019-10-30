import { next } from "@ember/runloop";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(GrantBadgeController, {
  adminUser: inject(),
  user: Ember.computed.alias("adminUser.model"),
  userBadges: Ember.computed.alias("model"),
  allBadges: Ember.computed.alias("badges"),
  sortedBadges: Ember.computed.sort("model", "badgeSortOrder"),

  init() {
    this._super(...arguments);

    this.badgeSortOrder = ["granted_at:desc"];
  },

  @computed("model", "model.[]", "model.expandedBadges.[]")
  groupedBadges() {
    const allBadges = this.model;

    var grouped = _.groupBy(allBadges, badge => badge.badge_id);

    var expanded = [];
    const expandedBadges = allBadges.get("expandedBadges") || [];

    _(grouped).each(function(badges) {
      var lastGranted = badges[0].granted_at;

      badges.forEach(badge => {
        lastGranted =
          lastGranted < badge.granted_at ? badge.granted_at : lastGranted;
      });

      if (badges.length === 1 || expandedBadges.includes(badges[0].badge.id)) {
        badges.forEach(badge => expanded.push(badge));
        return;
      }

      var result = {
        badge: badges[0].badge,
        granted_at: lastGranted,
        badges: badges,
        count: badges.length,
        grouped: true
      };

      expanded.push(result);
    });

    return _(expanded)
      .sortBy(group => group.granted_at)
      .reverse()
      .value();
  },

  actions: {
    expandGroup: function(userBadge) {
      const model = this.model;
      model.set("expandedBadges", model.get("expandedBadges") || []);
      model.get("expandedBadges").pushObject(userBadge.badge.id);
    },

    grantBadge() {
      this.grantBadge(
        this.selectedBadgeId,
        this.get("user.username"),
        this.badgeReason
      ).then(
        () => {
          this.set("badgeReason", "");
          next(() => {
            // Update the selected badge ID after the combobox has re-rendered.
            const newSelectedBadge = this.grantableBadges[0];
            if (newSelectedBadge) {
              this.set("selectedBadgeId", newSelectedBadge.get("id"));
            }
          });
        },
        function(error) {
          popupAjaxError(error);
        }
      );
    },

    revokeBadge(userBadge) {
      return bootbox.confirm(
        I18n.t("admin.badges.revoke_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            userBadge.revoke().then(() => {
              this.model.removeObject(userBadge);
            });
          }
        }
      );
    }
  }
});
