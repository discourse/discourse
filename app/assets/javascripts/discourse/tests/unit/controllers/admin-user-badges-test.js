import Badge from "discourse/models/badge";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | admin-user-badges", function () {
  test("grantableBadges", function (assert) {
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

    const controller = this.getController("admin-user-badges", {
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
    const badgeNames = controller.get("grantableBadges").map(function (badge) {
      return badge.name;
    });

    assert.notOk(
      badgeNames.includes(badgeDisabled),
      "excludes disabled badges"
    );
    assert.deepEqual(badgeNames, sortedNames, "sorts badges by name");
  });
});
