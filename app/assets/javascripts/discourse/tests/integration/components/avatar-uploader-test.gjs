import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AvatarUploader from "discourse/components/avatar-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  test("uploading", async function (assert) {
    const done = assert.async();

    pretender.post("/uploads.json", () => {
      assert.step("avatar is uploaded");
      return response({});
    });

    const callback = () => {
      assert.verifySteps(["avatar is uploaded"]);
      done();
    };

    await render(<template>
      <AvatarUploader @id="avatar-uploader" @done={{callback}} />
    </template>);

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:avatar-uploader:add-files", [
        createFile("avatar.png"),
      ]);
  });
});
