import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";
module("Unit | Utility | Grant Badge", function (hooks) {
  setupTest(hooks);

  test("grantableBadges", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const firstBadge = store.createRecord("badge", {
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    const middleBadge = store.createRecord("badge", {
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true,
    });
    const lastBadge = store.createRecord("badge", {
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: true,
    });
    const grantedBadge = store.createRecord("badge", {
      id: 6,
      name: "Grant Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: false,
    });
    const disabledBadge = store.createRecord("badge", {
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    const automaticBadge = store.createRecord("badge", {
      id: 5,
      name: "Automatic Badge",
      enabled: true,
      manually_grantable: false,
    });
    const allBadges = [
      lastBadge,
      firstBadge,
      middleBadge,
      grantedBadge,
      disabledBadge,
      automaticBadge,
    ];

    const userBadges = [lastBadge, grantedBadge].map((badge) => {
      return store.createRecord("user-badge", {
        badge_id: badge.id,
      });
    });
    const sortedNames = [firstBadge.name, middleBadge.name, lastBadge.name];

    const result = grantableBadges(allBadges, userBadges);
    const badgeNames = result.map((b) => b.name);

    assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
    assert.false(
      badgeNames.includes(grantedBadge.name),
      "excludes already granted badges"
    );
    assert.false(
      badgeNames.includes(disabledBadge.name),
      "excludes disabled badges"
    );
    assert.false(
      badgeNames.includes(automaticBadge.name),
      "excludes automatic badges"
    );
    assert.true(
      badgeNames.includes(lastBadge.name),
      "includes granted badges that can be granted multiple times"
    );
  });

  test("isBadgeGrantable", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const grantable_once_badge = store.createRecord("badge", {
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    const other_grantable_badge = store.createRecord("badge", {
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: true,
    });
    const disabledBadge = store.createRecord("badge", {
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    const badges = [grantable_once_badge, other_grantable_badge];
    assert.true(isBadgeGrantable(grantable_once_badge.id, badges));
    assert.false(
      isBadgeGrantable(disabledBadge.id, badges),
      "returns false when badgeId is not that of any badge in availableBadges"
    );
    assert.false(
      isBadgeGrantable(grantable_once_badge.id, []),
      "returns false if empty array availableBadges is passed in"
    );
    assert.false(
      isBadgeGrantable(grantable_once_badge.id, null),
      "returns false if no availableBadges is defined"
    );
  });
});
