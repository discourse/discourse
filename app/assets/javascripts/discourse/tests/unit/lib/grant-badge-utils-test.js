import { module, test } from "qunit";
import Badge from "discourse/models/badge";
import {
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";
module("Unit | Utility | Grant Badge", function (hooks) {
  hooks.beforeEach(() => {
    const firstBadge = Badge.create({
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    const middleBadge = Badge.create({
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true,
    });
    const lastBadge = Badge.create({
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: true,
    });
    const grantedBadge = Badge.create({
      id: 6,
      name: "Grant Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: false,
    });
    const disabledBadge = Badge.create({
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    const automaticBadge = Badge.create({
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
    const userBadges = [lastBadge, grantedBadge];

    test("grantableBadges", function (assert) {
      const sortedNames = [firstBadge.name, middleBadge.name, lastBadge.name];

      const result = grantableBadges(allBadges, userBadges);
      const badgeNames = result.map((b) => b.name);

      assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
      assert.notOk(
        badgeNames.includes(grantedBadge.name),
        "excludes already granted badges"
      );
      assert.notOk(
        badgeNames.includes(disabledBadge.name),
        "excludes disabled badges"
      );
      assert.notOk(
        badgeNames.includes(automaticBadge.name),
        "excludes automatic badges"
      );
      assert.ok(
        badgeNames.includes(lastBadge.name),
        "includes granted badges that can be granted multiple times"
      );
    });

    test("isBadgeGrantable", function (assert) {
      const badges = [firstBadge, lastBadge];
      assert.ok(isBadgeGrantable(firstBadge.id, badges));
      assert.notOk(
        isBadgeGrantable(disabledBadge.id, badges),
        "returns false when badgeId is not that of any badge in availableBadges"
      );
      assert.notOk(
        isBadgeGrantable(firstBadge.id),
        "returns false if no availableBadges is defined"
      );
    });
  });
});
