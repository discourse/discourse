import { module, test } from "qunit";
import Badge from "discourse/models/badge";
import Controller from "@ember/controller";
import GrantBadgeControllerMixin from "discourse/mixins/grant-badge-controller";

module("Unit | Mixin | grant-badge-controller", function (hooks) {
  hooks.beforeEach(function () {
    this.GrantBadgeController = Controller.extend(GrantBadgeControllerMixin);

    this.badgeFirst = Badge.create({
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    this.badgeMiddle = Badge.create({
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true,
    });
    this.badgeLast = Badge.create({
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
    });
    this.badgeDisabled = Badge.create({
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    this.badgeAutomatic = Badge.create({
      id: 5,
      name: "Automatic Badge",
      enabled: true,
      manually_grantable: false,
    });

    this.subject = this.GrantBadgeController.create({
      userBadges: [],
      allBadges: [
        this.badgeLast,
        this.badgeFirst,
        this.badgeMiddle,
        this.badgeDisabled,
        this.badgeAutomatic,
      ],
    });
  });

  test("grantableBadges", function (assert) {
    const sortedNames = [
      this.badgeFirst.name,
      this.badgeMiddle.name,
      this.badgeLast.name,
    ];
    const badgeNames = this.subject
      .get("grantableBadges")
      .map((badge) => badge.name);

    assert.notOk(
      badgeNames.includes(this.badgeDisabled),
      "excludes disabled badges"
    );
    assert.notOk(
      badgeNames.includes(this.badgeAutomatic),
      "excludes automatic badges"
    );
    assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
  });

  test("selectedBadgeGrantable", function (assert) {
    this.subject.set("selectedBadgeId", this.badgeDisabled.id);
    assert.notOk(this.subject.get("selectedBadgeGrantable"));

    this.subject.set("selectedBadgeId", this.badgeFirst.id);
    assert.ok(this.subject.get("selectedBadgeGrantable"));
  });
});
