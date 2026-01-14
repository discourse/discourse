import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | preferences/profile", function (hooks) {
  setupTest(hooks);

  test("prepare custom field data", function (assert) {
    const site = this.owner.lookup("service:site");
    site.set("user_fields", [
      { position: 1, id: 1, editable: true },
      { position: 2, id: 2, editable: true },
      { position: 3, id: 3, editable: true },
    ]);

    const controller = this.owner.lookup("controller:preferences/profile");
    const store = this.owner.lookup("service:store");
    controller.setProperties({
      model: store.createRecord("user", {
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

    controller.send("_updateUserFields");

    const fields = controller.model.user_fields;
    assert.strictEqual(fields[1], "2", "updates string value");
    assert.strictEqual(fields[2], null, "updates null");
    assert.strictEqual(fields[3], null, "updates empty array as null");
  });
});
