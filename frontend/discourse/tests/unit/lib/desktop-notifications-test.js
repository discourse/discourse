import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  canUserReceiveNotifications,
  context,
  init,
  setPushTransport,
} from "discourse/lib/desktop-notifications";
import KeyValueStore from "discourse/lib/key-value-store";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | desktop-notifications", function (hooks) {
  setupTest(hooks);

  const keyValueStore = new KeyValueStore(context);
  const user = { isInDoNotDisturb: () => false };

  hooks.beforeEach(function () {
    logIn(this.owner);
    sinon.stub(Notification, "permission").get(() => "granted");
    init({ clientId: "test-client" });
    // the test tab may be hidden; a focus event always marks it primary
    window.dispatchEvent(new Event("focus"));
  });

  hooks.afterEach(function () {
    keyValueStore.remove("notifications-disabled");
    setPushTransport(null);
  });

  test("suppresses in-tab alerts while push is delivering", function (assert) {
    assert.true(canUserReceiveNotifications(user));

    setPushTransport("delivering");

    assert.false(canUserReceiveNotifications(user));
  });

  test("the stored opt-out only rules while push is not standing in", function (assert) {
    keyValueStore.setItem("notifications-disabled", "disabled");

    assert.false(canUserReceiveNotifications(user));

    // older builds force-wrote the opt-out on every boot while push was on,
    // so it cannot silence the fallback for a broken push subscription
    setPushTransport("fallback");

    assert.true(canUserReceiveNotifications(user));
  });
});
