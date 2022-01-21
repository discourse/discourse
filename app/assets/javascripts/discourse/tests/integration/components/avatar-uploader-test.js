import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import {
  createFile,
  discourseModule,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/uploads.json", () => {
      return [200, { "Content-Type": "application/json" }, {}];
    });
  });

  componentTest("default", {
    template: hbs`{{avatar-uploader
      id="avatar-uploader"
      done=done
    }}`,

    async test(assert) {
      const done = assert.async();

      this.set("done", () => {
        assert.ok(true, "action is called after avatar is uploaded");
        done();
      });

      await this.container
        .lookup("service:app-events")
        .trigger("upload-mixin:avatar-uploader:add-files", [
          createFile("avatar.png"),
        ]);
    },
  });
});
