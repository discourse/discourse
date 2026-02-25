import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { compare, isEmpty } from "@ember/utils";
import AdminUser from "discourse/admin/models/admin-user";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  arraySortedByProperties,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { grantableBadges } from "discourse/lib/grant-badge-utils";
import { trackedArray } from "discourse/lib/tracked-tools";
import UserBadge from "discourse/models/user-badge";
import { i18n } from "discourse-i18n";

export default class AdminUserBadgesController extends Controller {
  @service dialog;
  @controller adminUser;

  @tracked loading;
  @tracked selectedBadgeId;
  @tracked model;
  @tracked badgeSortOrder = ["granted_at:desc"];
  @trackedArray badges;
  @trackedArray expandedBadges = [];

  @computed("adminUser.model")
  get user() {
    return this.adminUser?.model;
  }

  set user(value) {
    set(this, "adminUser.model", value);
  }

  @dependentKeyCompat
  get sortedBadges() {
    return arraySortedByProperties(this.model, this.badgeSortOrder);
  }

  @computed("availableBadges.length")
  get noAvailableBadges() {
    return isEmpty(this.availableBadges);
  }

  @dependentKeyCompat
  get allBadges() {
    return this.badges;
  }

  @dependentKeyCompat
  get userBadges() {
    return this.model;
  }

  @dependentKeyCompat
  get availableBadges() {
    return grantableBadges(this.allBadges, this.userBadges);
  }

  get groupedBadges() {
    const allBadges = this.model;

    let grouped = {};
    allBadges.forEach((b) => {
      grouped[b.badge_id] = grouped[b.badge_id] || [];
      grouped[b.badge_id].push(b);
    });

    let expanded = [];

    Object.values(grouped).forEach((badges) => {
      let lastGranted = badges[0].granted_at;

      badges.forEach((badge) => {
        lastGranted =
          lastGranted < badge.granted_at ? badge.granted_at : lastGranted;
      });

      if (
        badges.length === 1 ||
        this.expandedBadges.includes(badges[0].badge.id)
      ) {
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
    expanded.forEach((badgeGroup) => {
      const user = badgeGroup.granted_by;
      if (user) {
        badgeGroup.granted_by = AdminUser.create(user);
      }
    });

    return expanded.sort((a, b) => compare(b?.granted_at, a?.granted_at)); // sort descending
  }

  @action
  expandGroup(userBadge) {
    this.expandedBadges.push(userBadge.badge.id);
  }

  @action
  async performGrantBadge() {
    try {
      const newBadge = await UserBadge.grant(
        this.selectedBadgeId,
        this.get("user.username"),
        this.badgeReason
      );

      this.set("badgeReason", "");
      this.model.push(newBadge);
      next(() => {
        // Update the selected badge ID after the combobox has re-rendered.
        const newSelectedBadge = this.availableBadges[0];
        if (newSelectedBadge) {
          this.set("selectedBadgeId", newSelectedBadge.get("id"));
        }
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  revokeBadge(userBadge) {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.badges.revoke_confirm"),
      didConfirm: async () => {
        await userBadge.revoke();
        removeValueFromArray(this.model, userBadge);
      },
    });
  }
}
