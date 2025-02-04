import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";

module("Unit | Controller | admin-user-badges", function (hooks) {
  setupTest(hooks);

  test("availableBadges", function (assert) {
    const badgeFirst = Badge.create({
      id: 3,
      name: "A Badge",
      enabled: true,
      manually_grantable: true,
    });
    const badgeMiddle = Badge.create({
      id: 1,
      name: "My Badge",
      enabled: true,
      manually_grantable: true,
    });
    const badgeLast = Badge.create({
      id: 2,
      name: "Zoo Badge",
      enabled: true,
      manually_grantable: true,
    });
    const badgeDisabled = Badge.create({
      id: 4,
      name: "Disabled Badge",
      enabled: false,
      manually_grantable: true,
    });
    const badgeAutomatic = Badge.create({
      id: 5,
      name: "Automatic Badge",
      enabled: true,
      manually_grantable: false,
    });

    const controller = this.owner.lookup("controller:admin-user-badges");
    controller.setProperties({
      model: [],
      badges: [
        badgeLast,
        badgeFirst,
        badgeMiddle,
        badgeDisabled,
        badgeAutomatic,
      ],
    });

    const sortedNames = [badgeFirst.name, badgeMiddle.name, badgeLast.name];
    const badgeNames = controller.availableBadges.map((badge) => badge.name);

    assert.false(
      badgeNames.includes(badgeDisabled),
      "excludes disabled badges"
    );
    assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
  });

  test("performGrantBadge", async function (assert) {
    const GrantBadgeStub = sinon.stub(UserBadge, "grant");
    const controller = this.owner.lookup("controller:admin-user-badges");
    const store = this.owner.lookup("service:store");

    const badgeToGrant = store.createRecord("badge", {
      id: 3,
      name: "Granted Badge",
      enabled: true,
      manually_grantable: true,
    });

    const otherBadge = store.createRecord("badge", {
      id: 4,
      name: "Other Badge",
      enabled: true,
      manually_grantable: true,
    });

    const badgeReason = "Test Reason";

    const user = { username: "jb", name: "jack black", id: 42 };

    controller.setProperties({
      model: [],
      adminUser: { model: user },
      badgeReason,
      selectedBadgeId: badgeToGrant.id,
      badges: [badgeToGrant, otherBadge],
    });

    const newUserBadge = store.createRecord("badge", {
      id: 88,
      badge_id: badgeToGrant.id,
      user_id: user.id,
    });

    GrantBadgeStub.returns(Promise.resolve(newUserBadge));
    controller.performGrantBadge();
    await settled();

    assert.true(
      GrantBadgeStub.calledWith(badgeToGrant.id, user.username, badgeReason)
    );

    assert.strictEqual(controller.badgeReason, "");
    assert.strictEqual(controller.userBadges.length, 1);
    assert.strictEqual(controller.userBadges[0].id, newUserBadge.id);
    assert.strictEqual(controller.selectedBadgeId, otherBadge.id);
  });
});
