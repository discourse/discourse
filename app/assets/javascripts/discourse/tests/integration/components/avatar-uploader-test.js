import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/uploads.json", () => response({}));
  });

  test("default", async function (assert) {
    const done = assert.async();
    this.set("done", () => {
      assert.ok(true, "action is called after avatar is uploaded");
      done();
    });

    await render(hbs`
      <AvatarUploader
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
