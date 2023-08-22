import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import EmberObject from "@ember/object";
import User from "discourse/models/user";

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
});
