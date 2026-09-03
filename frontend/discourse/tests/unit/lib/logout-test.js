import { module, test } from "qunit";
import logout from "discourse/lib/logout";
import { pushNotificationConfirmationStore } from "discourse/lib/push-notifications";

module("Unit | Lib | logout", function (hooks) {
  hooks.afterEach(function () {
    pushNotificationConfirmationStore.remove("active");
  });

  test("clears the active push endpoint confirmation", function (assert) {
    pushNotificationConfirmationStore.setObject({
      key: "active",
      value: { userId: 42, endpoint: "current" },
    });

    logout();

    assert.strictEqual(
      pushNotificationConfirmationStore.getObject("active"),
      undefined
    );
  });
});
