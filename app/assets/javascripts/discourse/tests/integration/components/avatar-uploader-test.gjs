import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AvatarUploader from "discourse/components/avatar-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.post("/uploads.json", () => response({}));
  });

  test("default", async function (assert) {
    const done = () => assert.step("avatar is uploaded");

    await render(<template>
      <AvatarUploader @id="avatar-uploader" @done={{done}} />
    </template>);

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:avatar-uploader:add-files", [
        createFile("avatar.png"),
      ]);

    assert.verifySteps(["avatar is uploaded"]);
  });
});
