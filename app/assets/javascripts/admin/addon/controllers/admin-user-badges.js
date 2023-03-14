import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { alias, sort } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { next } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminUserBadgesController extends Controller.extend(
  GrantBadgeController
) {
  @service dialog;
  @controller adminUser;

  @alias("adminUser.model") user;

  @alias("model") userBadges;

  @alias("badges") allBadges;

  @sort("model", "badgeSortOrder") sortedBadges;

  init() {
    super.init(...arguments);

    this.badgeSortOrder = ["granted_at:desc"];
  }

  @discourseComputed("model", "model.[]", "model.expandedBadges.[]")
  groupedBadges() {
    const allBadges = this.model;

    let grouped = {};
    allBadges.forEach((b) => {
      grouped[b.badge_id] = grouped[b.badge_id] || [];
      grouped[b.badge_id].push(b);
    });

    let expanded = [];
    const expandedBadges = allBadges.get("expandedBadges") || [];

    Object.values(grouped).forEach(function (badges) {
      let lastGranted = badges[0].granted_at;

      badges.forEach((badge) => {
        lastGranted =
          lastGranted < badge.granted_at ? badge.granted_at : lastGranted;
      });

      if (badges.length === 1 || expandedBadges.includes(badges[0].badge.id)) {
        badges.forEach((badge) => expanded.push(badge));
        return;
      }

      let result = {
        badge: badges[0].badge,
        granted_at: lastGranted,
        badges,
        count: badges.length,
        grouped: true,
      };

      expanded.push(result);
    });

    return expanded.sortBy("granted_at").reverse();
  }

  @action
  expandGroup(userBadge) {
    const model = this.model;
    model.set("expandedBadges", model.get("expandedBadges") || []);
    model.get("expandedBadges").pushObject(userBadge.badge.id);
  }

  @action
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
      function (error) {
        popupAjaxError(error);
      }
    );
  }

  @action
  revokeBadge(userBadge) {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.badges.revoke_confirm"),
      didConfirm: () => {
        return userBadge.revoke().then(() => {
          this.model.removeObject(userBadge);
        });
      },
    });
  }
}
