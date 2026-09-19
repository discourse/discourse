import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Route | admin-backups", function (hooks) {
  setupTest(hooks);

  test("[STARTED] clears the logs and marks the operation as running", function (assert) {
    const currentUser = logIn(this.owner);
    const route = this.owner.lookup("route:admin.backups");

    const backupsController = EmberObject.create({
      model: EmberObject.create({
        isOperationRunning: false,
      }),
    });

    const logsController = this.owner.lookup("controller:admin.backups.logs");
    const logs = logsController.logs;

    logs.push(EmberObject.create({ message: "existing log" }));

    route.controllerFor = (name) => {
      if (name === "admin.backups") {
        return backupsController;
      }

      if (name === "admin.backups.logs") {
        return logsController;
      }
    };

    route.onMessage({ message: "[STARTED]" });

    assert.true(currentUser.get("hideReadOnlyAlert"));
    assert.true(backupsController.get("model.isOperationRunning"));
    assert.strictEqual(logs.length, 0, "existing log entries are removed");
    assert.strictEqual(
      logsController.logs,
      logs,
      "the existing tracked array object is preserved"
    );
  });
});
