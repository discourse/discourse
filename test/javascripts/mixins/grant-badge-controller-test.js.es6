import Controller from "@ember/controller";
import GrantBadgeControllerMixin from "discourse/mixins/grant-badge-controller";
import Badge from "discourse/models/badge";

QUnit.module("mixin:grant-badge-controller", {
  before: function() {
    this.GrantBadgeController = Controller.extend(GrantBadgeControllerMixin);

    this.badgeFirst = Badge.create({
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true
    });
    this.badgeMiddle = Badge.create({
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true
    });
    this.badgeLast = Badge.create({
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true
    });
    this.badgeDisabled = Badge.create({
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true
    });
    this.badgeAutomatic = Badge.create({
      id: 5,
      name: "Automatic Badge",
      enabled: true,
      manually_grantable: false
    });
  },

  beforeEach: function() {
    this.subject = this.GrantBadgeController.create({
      userBadges: [],
      allBadges: [
        this.badgeLast,
        this.badgeFirst,
        this.badgeMiddle,
        this.badgeDisabled,
        this.badgeAutomatic
      ]
    });
  }
});

QUnit.test("grantableBadges", function(assert) {
  const sortedNames = [
    this.badgeFirst.name,
    this.badgeMiddle.name,
    this.badgeLast.name
  ];
  const badgeNames = this.subject
    .get("grantableBadges")
    .map(badge => badge.name);

  assert.not(
    badgeNames.includes(this.badgeDisabled),
    "excludes disabled badges"
  );
  assert.not(
    badgeNames.includes(this.badgeAutomatic),
    "excludes automatic badges"
  );
  assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
});

QUnit.test("selectedBadgeGrantable", function(assert) {
  this.subject.set("selectedBadgeId", this.badgeDisabled.id);
  assert.not(this.subject.get("selectedBadgeGrantable"));

  this.subject.set("selectedBadgeId", this.badgeFirst.id);
  assert.ok(this.subject.get("selectedBadgeGrantable"));
});
