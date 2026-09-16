import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import TopicDetails from "discourse/models/topic-details";
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

  // The base constructor seeds registered fields and fires `init` callbacks
  // before this subclass's own (private) state exists.
  test("a plugin init callback can read id and __resource during construction", function (assert) {
    let seen;
    withPluginApi((api) =>
      api.addModelCallback("topic-details", "init", function () {
        seen = { id: this.id, resource: this.__resource };
      })
    );

    const details = TopicDetails.create({ id: 123 });

    assert.deepEqual(
      seen,
      { id: null, resource: undefined },
      "reports no id while the base constructor runs"
    );
    assert.strictEqual(details.id, "123", "resolves the id afterwards");
  });

  test("a plugin-registered field seeds its default", function (assert) {
    withPluginApi((api) =>
      api.addModelField("topic-details", "pluginFlag", { defaultValue: 7 })
    );

    const details = TopicDetails.create({ id: 55 });

    assert.strictEqual(details.pluginFlag, 7, "applies the registered default");
    assert.strictEqual(details.id, "55");
  });
});
