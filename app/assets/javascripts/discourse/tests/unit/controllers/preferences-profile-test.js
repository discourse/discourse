import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import EmberObject from "@ember/object";
import User from "discourse/models/user";

discourseModule("Unit | Controller | preferences/profile", function () {
  test("prepare custom field data", function (assert) {
    const controller = this.getController("preferences/profile", {
      model: User.create({
        id: 70,
        second_factor_enabled: true,
        is_anonymous: true,
        user_fields: {
          field_1: "1",
          field_2: "2",
          field_3: "3",
        },
      }),
      currentUser: {
        id: 1234,
      },
    });
    controller.set("userFields", [
      EmberObject.create({ value: "2", field: { id: "field_1" } }),
      EmberObject.create({ value: null, field: { id: "field_2" } }),
      EmberObject.create({ value: [], field: { id: "field_3" } }),
    ]);
    controller.send("_updateUserFields");
    assert.equal(
      controller.model.user_fields.field_1,
      "2",
      "updates string value"
    );
    assert.equal(controller.model.user_fields.field_2, null, "updates null");
    assert.equal(
      controller.model.user_fields.field_3,
      null,
      "updates empty array as null"
    );
  });
});
