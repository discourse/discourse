import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import WatchedWordUploader from "admin/components/watched-word-uploader";

module("Integration | Component | watched-word-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/admin/customize/watched_words/upload.json", function () {
      return response(200, {});
    });
  });

  test("sets the proper action key on uploads", async function (assert) {
    const self = this;

    const dialog = getOwner(this).lookup("service:dialog");
    sinon.stub(dialog, "alert");

    const done = assert.async();
    this.set("actionNameKey", "flag");
    this.set("doneUpload", function () {
      assert.strictEqual(
        Object.entries(
          this.uppyUpload.uppyWrapper.uppyInstance.getState().files
        )[0][1].meta.action_key,
        "flag"
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
          @actionKey={{self.actionNameKey}}
          @done={{self.doneUpload}}
        />
      </template>
    );

    const words = createFile("watched-words.txt");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:watched-word-uploader:add-files", words);
  });
});
