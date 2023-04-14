import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import EmberObject from "@ember/object";
import * as showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";
import I18n from "I18n";

module("Unit | Controller | user-notifications", function (hooks) {
  setupTest(hooks);

  test("Mark read marks all models read when response is 200", async function (assert) {
    const model = [
      EmberObject.create({ read: false }),
      EmberObject.create({ read: false }),
    ];
    const controller = this.owner.lookup("controller:user-notifications");
    controller.setProperties({ model });
    pretender.put("/notifications/mark-read", () => response({}));

    await controller.markRead();

    assert.strictEqual(
      model.every(({ read }) => read === true),
      true
    );
  });

  test("Mark read does not mark models read when response is not successful", async function (assert) {
    const model = [
      EmberObject.create({ read: false }),
      EmberObject.create({ read: true }),
    ];
    const controller = this.owner.lookup("controller:user-notifications");
    controller.setProperties({ model });
    pretender.put("/notifications/mark-read", () => response(500));

    assert.rejects(controller.markRead());
    assert.deepEqual(
      model.map(({ read }) => read),
      [false, true],
      "models unmodified"
    );
  });

  test("Marks all notifications read when no high priority notifications", function (assert) {
    let markRead = false;
    const currentUser = User.create({ unread_high_priority_notifications: 0 });
    const controller = this.owner.lookup("controller:user-notifications");
    controller.setProperties({
      model: [],
      currentUser,
    });
    sinon.stub(controller, "markRead").callsFake(() => (markRead = true));

    controller.send("resetNew");

    assert.strictEqual(markRead, true);
  });

  test("Shows modal when has high priority notifications", function (assert) {
    let capturedProperties;
    sinon
      .stub(showModal, "default")
      .withArgs("dismiss-notification-confirmation")
      .returns({
        setProperties: (properties) => (capturedProperties = properties),
      });

    const currentUser = User.create({ unread_high_priority_notifications: 1 });
    const controller = this.owner.lookup("controller:user-notifications");
    controller.setProperties({ currentUser });
    const markReadFake = sinon.fake();
    sinon.stub(controller, "markRead").callsFake(markReadFake);

    controller.send("resetNew");

    assert.strictEqual(
      capturedProperties.confirmationMessage,
      I18n.t("notifications.dismiss_confirmation.body.default", { count: 1 })
    );
    capturedProperties.dismissNotifications();
    assert.strictEqual(markReadFake.callCount, 1);
  });
});
