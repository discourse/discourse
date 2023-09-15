import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwner } from "@ember/application";
import {
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";

module("Unit | Utility | Grant Badge", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    this.firstBadge = store.createRecord("badge", {
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    this.middleBadge = store.createRecord("badge", {
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true,
    });
    this.lastBadge = store.createRecord("badge", {
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: true,
    });
    this.grantedBadge = store.createRecord("badge", {
      id: 6,
      name: "Grant Badge",
      enabled: true,
      manually_grantable: true,
      multiple_grant: false,
    });
    this.disabledBadge = store.createRecord("badge", {
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    this.automaticBadge = store.createRecord("badge", {
      id: 5,
      name: "Automatic Badge",
      enabled: true,
      manually_grantable: false,
    });
  });

  test("grantableBadges", function (assert) {
    const allBadges = [
      this.lastBadge,
      this.firstBadge,
      this.middleBadge,
      this.grantedBadge,
      this.disabledBadge,
      this.automaticBadge,
    ];
    const userBadges = [this.lastBadge, this.grantedBadge];
    const sortedNames = [
      this.firstBadge.name,
      this.middleBadge.name,
      this.lastBadge.name,
    ];

    const result = grantableBadges(allBadges, userBadges);
    const badgeNames = result.map((b) => b.name);

    assert.false(
      badgeNames.includes(this.grantedBadge.name),
      "excludes already granted badges"
    );
    assert.false(
      badgeNames.includes(this.disabledBadge.name),
      "excludes disabled badges"
    );
    assert.false(
      badgeNames.includes(this.automaticBadge.name),
      "excludes automatic badges"
    );
    assert.true(
      badgeNames.includes(this.lastBadge.name),
      "includes granted badges that can be granted multiple times"
    );
    assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
  });

  test("isBadgeGrantable", function (assert) {
    const badges = [this.firstBadge, this.lastBadge];
    assert.true(isBadgeGrantable(this.firstBadge.id, badges));
    assert.false(
      isBadgeGrantable(this.disabledBadge.id, badges),
      "returns false when badgeId is not that of any badge in availableBadges"
    );
    assert.false(
      isBadgeGrantable(this.firstBadge.id),
      "returns false if no availableBadges is defined"
    );
  });
});
