import { getOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import { render, triggerEvent, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import UppyBackupUploader from "discourse/admin/components/uppy-backup-uploader";
import BackupsIndex from "discourse/admin/templates/admin/backups/index";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

module("Integration | Component | UppyBackupUploader", function (hooks) {
  setupRenderingTest(hooks);

  test("re-rendering mid-upload shows the upload in progress", async function (assert) {
    this.siteSettings.backup_location = "local";
    const alert = sinon.stub(getOwner(this).lookup("service:dialog"), "alert");

    let requested = false;
    let respond;
    const responded = new Promise((resolve) => (respond = resolve));
    pretender.post("/admin/backups/upload.json", async () => {
      requested = true;
      await responded;
      return response({});
    });

    const { uppyUpload } = getOwner(this).lookup(
      "controller:admin.backups.index"
    );

    await render(
      <template><UppyBackupUploader @uppyUpload={{uppyUpload}} /></template>
    );

    await triggerEvent(".hidden-upload-field", "change", {
      files: [createFile("backup.tar.gz", "application/gzip")],
    });
    await waitUntil(() => requested, { timeout: 5000 });

    // Replaces the uploader with a new one
    await render(
      <template><UppyBackupUploader @uppyUpload={{uppyUpload}} /></template>
    );

    assert
      .dom(".admin-backups-upload")
      .hasAttribute("disabled", "", "disables the new uploader")
      .includesText("Uploading…", "shows the upload in progress");

    const uppyInstance = uppyUpload.uppyWrapper.uppyInstance;
    respond();
    await waitUntil(() => alert.called, { timeout: 5000 });

    assert.true(
      alert.calledWith(
        i18n("admin.backups.upload.success", { filename: "backup.tar.gz" })
      ),
      "reports the finished upload"
    );
    assert
      .dom(".admin-backups-upload")
      .hasText(i18n("admin.backups.upload.label"), "resets the uploader");
    assert.strictEqual(
      uppyUpload.uppyWrapper.uppyInstance,
      uppyInstance,
      "doesn't recreate Uppy when the upload finishes"
    );
  });

  test("refreshes the list after a remote upload", async function (assert) {
    this.siteSettings.backup_location = "s3";
    pretender.post("/admin/backups/upload.json", () => response({}));
    pretender.get("/admin/backups.json", () =>
      response([{ filename: "backup.tar.gz", size: 1024 }])
    );

    const controller = getOwner(this).lookup("controller:admin.backups.index");
    controller.model = trackedArray();

    await render(
      <template><BackupsIndex @controller={{controller}} /></template>
    );
    await triggerEvent(".hidden-upload-field", "change", {
      files: [createFile("backup.tar.gz", "application/gzip")],
    });
    await waitUntil(() => document.querySelector(".backup-item-row"), {
      timeout: 5000,
    });

    assert
      .dom(".backup-item-row")
      .hasAttribute(
        "data-backup-filename",
        "backup.tar.gz",
        "shows the uploaded backup"
      );
  });
});
