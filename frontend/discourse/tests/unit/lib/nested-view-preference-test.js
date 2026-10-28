import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { adoptAnonymousFlatRepliesPreference } from "discourse/lib/nested-view-preference";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | nested-view-preference", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.keyValueStore = this.owner.lookup("service:key-value-store");
  });

  hooks.afterEach(function () {
    this.keyValueStore.remove("prefer_flat_replies");
  });

  test("copies the anonymous flat preference to the account", async function (assert) {
    const user = logIn(this.owner);
    let savedValue;
    pretender.put("/u/eviltrout.json", (request) => {
      savedValue = new URLSearchParams(request.requestBody).get(
        "prefer_flat_replies"
      );
      return response(200, { user: {} });
    });
    this.keyValueStore.set({ key: "prefer_flat_replies", value: "true" });

    await adoptAnonymousFlatRepliesPreference(user, this.keyValueStore);

    assert.strictEqual(savedValue, "true");
    assert.true(user.user_option.prefer_flat_replies);
    assert.strictEqual(
      this.keyValueStore.get("prefer_flat_replies"),
      undefined
    );
  });

  test("does nothing without an anonymous preference", async function (assert) {
    const user = logIn(this.owner);
    let requests = 0;
    pretender.put("/u/eviltrout.json", () => {
      requests++;
      return response(200, { user: {} });
    });

    await adoptAnonymousFlatRepliesPreference(user, this.keyValueStore);

    assert.strictEqual(requests, 0);
    assert.false(!!user.user_option.prefer_flat_replies);
  });
});
