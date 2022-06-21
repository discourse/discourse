import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  createFile,
  discourseModule,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { click, waitFor } from "@ember/test-helpers";

discourseModule(
  "Integration | Component | watched-word-uploader",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.post("/admin/customize/watched_words/upload.json", function () {
        return response(200, {});
      });
    });

    componentTest("sets the proper action key on uploads", {
      template: hbs`{{watched-word-uploader
        id="watched-word-uploader"
        actionKey=actionNameKey
        done=doneUpload
      }}`,

      async test(assert) {
        const done = assert.async();
        this.set("actionNameKey", "flag");
        this.set("doneUpload", function () {
          assert.equal(
            Object.entries(this._uppyInstance.getState().files)[0][1].meta
              .action_key,
            "flag"
          );
          done();
        });

        const words = createFile("watched-words.txt");
        await this.container
          .lookup("service:app-events")
          .trigger("upload-mixin:watched-word-uploader:add-files", words);
        await waitFor(".bootbox span.d-button-label");
        await click(".bootbox span.d-button-label");
      },
    });
  }
);
