import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import * as showModal from "discourse/lib/show-modal";
import sinon from "sinon";
import EmberObject from "@ember/object";
import User from "discourse/models/user";
import pretender from "discourse/tests/helpers/create-pretender";

discourseModule("Unit | Controller | user-notifications", function () {
  test("Mark read marks all models read when response is 200", async function (assert) {
    const model = [
      EmberObject.create({ read: false }),
      EmberObject.create({ read: false }),
    ];
    const controller = this.getController("user-notifications", {
      model,
    });
    pretender.put("/notifications/mark-read", () => {
      return [200];
    });

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
    let markModelsRead = false;
    const controller = this.getController("user-notifications", {
      model,
      markModelsRead: () => {
        markModelsRead = true;
      },
    });
    pretender.put("/notifications/mark-read", () => {
      return [500];
    });

    assert.rejects(controller.markRead());
    assert.strictEqual(markModelsRead, false);
  });

  test("Marks all notifications read when no high priority notifications", function (assert) {
    let markRead = false;
    const currentUser = User.create({ unread_high_priority_notifications: 0 });
    const controller = this.getController("user-notifications", {
      model: [],
      currentUser,
      markRead: () => {
        markRead = true;
      },
    });

    controller.send("resetNew");

    assert.strictEqual(markRead, true);
  });

  test("Shows modal when has high priority notifications", function (assert) {
    let capturedProperties;
    const markReadStub = () => {};
    sinon
      .stub(showModal, "default")
      .withArgs("dismiss-notification-confirmation")
      .returns({
        setProperties: (properties) => (capturedProperties = properties),
      });
    const currentUser = User.create({ unread_high_priority_notifications: 1 });
    const controller = this.getController("user-notifications", {
      currentUser,
      markRead: markReadStub,
    });

    controller.send("resetNew");

    assert.strictEqual(capturedProperties.count, 1);
    assert.strictEqual(
      capturedProperties.dismissNotifications(),
      markReadStub()
    );
  });
});
