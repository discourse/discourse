import { getOwner } from "@ember/owner";
import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import WatchedWordUploader from "discourse/admin/components/watched-word-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

module("Integration | Component | WatchedWordUploader", function (hooks) {
  setupRenderingTest(hooks);

  let uploadedActionKey;

  hooks.beforeEach(function () {
    uploadedActionKey = undefined;

    pretender.post(
      "/admin/customize/watched_words/upload.json",
      function (request) {
        uploadedActionKey = request.requestBody.get("action_key");
        return response(200, {});
      }
    );
  });

  test("sets the proper action key on uploads", async function (assert) {
    const dialog = getOwner(this).lookup("service:dialog");
    sinon.stub(dialog, "alert");

    const done = assert.async();
    this.set("actionNameKey", "flag");
    this.set("doneUpload", () => {
      assert.strictEqual(
        uploadedActionKey,
        "flag",
        "sends the action key with the upload"
      );
      assert.true(
        dialog.alert.calledWith(
          i18n("admin.watched_words.form.upload_successful")
        ),
        "alert shown"
      );
      done();
    });

    await render(
      <template>
        <WatchedWordUploader
          @actionKey={{this.actionNameKey}}
          @done={{this.doneUpload}}
        />
      </template>
    );

    const words = createFile("watched-words.txt");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:watched-word-uploader:add-files", words);
  });

  test("waits for the upload runtime before binding its input", async function (assert) {
    let finishLoading;
    const loading = new Promise((resolve) => (finishLoading = resolve));
    this.owner.register(
      "service:upload-runtime",
      class extends Service {
        loaded = false;

        load() {
          return loading;
        }
      }
    );

    await render(
      <template><WatchedWordUploader @actionKey="flag" /></template>
    );
    assert
      .dom(".hidden-upload-field")
      .doesNotExist("the input waits for the runtime");

    finishLoading();
    await settled();
    assert
      .dom(".hidden-upload-field")
      .exists("the input mounts once the runtime is ready");
  });
});
