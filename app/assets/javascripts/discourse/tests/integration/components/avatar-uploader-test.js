import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";

module("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/uploads.json", () => {
      return [200, { "Content-Type": "application/json" }, {}];
    });
  });

  test("default", async function (assert) {
    const done = assert.async();
    this.set("done", () => {
      assert.ok(true, "action is called after avatar is uploaded");
      done();
    });

    await render(hbs`
      <AvatarUploader
        @id="avatar-uploader"
        @done={{this.done}}
      />
    `);

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:avatar-uploader:add-files", [
        createFile("avatar.png"),
      ]);
  });
});
