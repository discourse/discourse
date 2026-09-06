import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminBackupsLogs from "discourse/admin/components/admin-backups-logs";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

function createLog(timestamp, message) {
  return EmberObject.create({ timestamp, message });
}

module("Integration | Component | AdminBackupsLogs", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an empty state when there are no logs", async function (assert) {
    const logs = trackedArray();

    await render(
      <template>
        <AdminBackupsLogs @logs={{logs}} class="custom-backup-logs" />
      </template>
    );

    assert
      .dom(".admin-backups-logs")
      .hasClass("custom-backup-logs", "caller-supplied classes are forwarded");
    assert
      .dom(".admin-backups-logs p")
      .hasText(i18n("admin.backups.logs.none"), "the empty state is shown");
    assert
      .dom(".admin-backups-logs pre")
      .doesNotExist("no log output is rendered");
  });

  test("renders initial logs in order", async function (assert) {
    const logs = trackedArray([
      createLog("10:00:00", "Starting backup"),
      createLog("10:00:01", "Dumping database"),
    ]);

    await render(<template><AdminBackupsLogs @logs={{logs}} /></template>);

    assert
      .dom(".admin-backups-logs pre")
      .hasText(
        "[10:00:00] Starting backup\n[10:00:01] Dumping database",
        "the initial logs are rendered in order"
      );
  });

  test("appends multiple logs reactively", async function (assert) {
    const logs = trackedArray([createLog("10:00:00", "Starting backup")]);

    await render(<template><AdminBackupsLogs @logs={{logs}} /></template>);

    logs.push(
      createLog("10:00:01", "Dumping database"),
      createLog("10:00:02", "Backup complete")
    );
    await settled();

    assert
      .dom(".admin-backups-logs pre")
      .hasText(
        "[10:00:00] Starting backup\n[10:00:01] Dumping database\n[10:00:02] Backup complete",
        "the appended logs are rendered after the initial log"
      );
  });

  test("starts fresh after logs are cleared", async function (assert) {
    const logs = trackedArray([
      createLog("10:00:00", "Old log"),
      createLog("10:00:01", "Another old log"),
    ]);

    await render(<template><AdminBackupsLogs @logs={{logs}} /></template>);

    logs.length = 0;
    await settled();

    assert
      .dom(".admin-backups-logs p")
      .hasText(i18n("admin.backups.logs.none"), "the empty state is restored");
    assert
      .dom(".admin-backups-logs pre")
      .doesNotExist("the old log output is removed");

    logs.push(createLog("11:00:00", "New backup"));
    await settled();

    assert
      .dom(".admin-backups-logs pre")
      .hasText(
        "[11:00:00] New backup",
        "only logs added after the reset are rendered"
      );
  });

  test("starts fresh when logs are cleared and repopulated together", async function (assert) {
    const logs = trackedArray([createLog("10:00:00", "Old log")]);

    await render(<template><AdminBackupsLogs @logs={{logs}} /></template>);

    logs.length = 0;
    logs.push(createLog("11:00:00", "New backup"));
    await settled();

    assert
      .dom(".admin-backups-logs pre")
      .hasText("[11:00:00] New backup", "only the replacement log is rendered");
  });

  test("updates the operation spinner reactively", async function (assert) {
    const logs = trackedArray();
    const status = EmberObject.create({ isOperationRunning: false });

    await render(
      <template>
        <AdminBackupsLogs @logs={{logs}} @status={{status}} />
      </template>
    );

    assert
      .dom(".admin-backups-logs .spinner")
      .doesNotExist("the spinner is hidden while no operation is running");

    status.set("isOperationRunning", true);
    await settled();

    assert
      .dom(".admin-backups-logs .spinner")
      .exists("the spinner is shown while an operation is running");

    status.set("isOperationRunning", false);
    await settled();

    assert
      .dom(".admin-backups-logs .spinner")
      .doesNotExist("the spinner is hidden when the operation finishes");
  });
});
