import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import sinon from "sinon";
import I18n from "I18n";
import { dialog } from "discourse/lib/uploads";

module("Integration | Component | watched-word-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/admin/customize/watched_words/upload.json", function () {
      return response(200, {});
    });
  });

  test("sets the proper action key on uploads", async function (assert) {
    sinon.stub(dialog, "alert");

    const done = assert.async();
    this.set("actionNameKey", "flag");
    this.set("doneUpload", function () {
      assert.strictEqual(
        Object.entries(this._uppyInstance.getState().files)[0][1].meta
          .action_key,
        "flag"
      );
      assert.ok(
        dialog.alert.calledWith(
          I18n.t("admin.watched_words.form.upload_successful")
        ),
        "alert shown"
      );
      done();
    });

    await render(hbs`
      <WatchedWordUploader
        @id="watched-word-uploader"
        @actionKey={{this.actionNameKey}}
        @done={{this.doneUpload}}
      />
    `);

    const words = createFile("watched-words.txt");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:watched-word-uploader:add-files", words);
  });
});
