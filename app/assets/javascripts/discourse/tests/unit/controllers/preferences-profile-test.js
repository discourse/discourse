import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import User from "discourse/models/user";
import Site from "discourse/models/site";

discourseModule("Unit | Controller | preferences/profile", function () {
  test("prepare custom field data", function (assert) {
    const controller = this.getController("preferences/profile", {
      model: User.create({
        id: 70,
        second_factor_enabled: true,
        is_anonymous: true,
        user_fields: {
          1: "2",
          2: null,
          3: [],
        },
      }),
      currentUser: {
        id: 1234,
      },
    });

    Site.currentProp("user_fields", [
      { position: 1, id: 1, editable: true },
      { position: 2, id: 2, editable: true },
      { position: 3, id: 3, editable: true },
    ]);

    // Since there are no injections in unit tests
    controller.set("site", Site.current());

    controller.send("_updateUserFields");

    const fields = controller.model.user_fields;
    assert.strictEqual(fields[1], "2", "updates string value");
    assert.strictEqual(fields[2], null, "updates null");
    assert.strictEqual(fields[3], null, "updates empty array as null");
  });
});
