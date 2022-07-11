import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, waitFor } from "@ember/test-helpers";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | watched-word-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/admin/customize/watched_words/upload.json", function () {
      return response(200, {});
    });
  });

  test("sets the proper action key on uploads", async function (assert) {
    const done = assert.async();
    this.set("actionNameKey", "flag");
    this.set("doneUpload", function () {
      assert.strictEqual(
        Object.entries(this._uppyInstance.getState().files)[0][1].meta
          .action_key,
        "flag"
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
    await waitFor(".bootbox span.d-button-label");

    await click(".bootbox span.d-button-label");
  });
});
