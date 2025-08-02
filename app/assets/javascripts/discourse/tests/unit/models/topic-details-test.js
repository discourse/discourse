import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import User from "discourse/models/user";

module("Unit | Model | topic-details", function (hooks) {
  setupTest(hooks);

  test("defaults", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1234 });
    const details = topic.details;

    assert.present(details, "the details are present by default");
    assert.false(details.loaded, "details are not loaded by default");
  });

  test("updateFromJson", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1234 });
    const details = topic.details;

    details.updateFromJson({
      allowed_users: [{ username: "eviltrout" }],
    });

    assert.strictEqual(
      details.allowed_users.length,
      1,
      "it loaded the allowed users"
    );
    assert.containsInstance(details.allowed_users, User);
  });
});
