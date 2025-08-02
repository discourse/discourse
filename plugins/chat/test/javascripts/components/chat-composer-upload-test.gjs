import { fn } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatComposerUpload from "discourse/plugins/chat/discourse/components/chat-composer-upload";

module("Discourse Chat | Component | chat-composer-upload", function (hooks) {
  setupRenderingTest(hooks);

  test("file - uploading in progress", async function (assert) {
    const self = this;

    this.set("upload", {
      progress: 50,
      extension: ".pdf",
      fileName: "test.pdf",
    });

    await render(
      <template><ChatComposerUpload @upload={{self.upload}} /></template>
    );

    assert.dom(".upload-progress[value='50']").exists();
    assert.dom(".uploading").hasText(i18n("uploading"));
  });

  test("image - uploading in progress", async function (assert) {
    const self = this;

    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
    });

    await render(
      <template><ChatComposerUpload @upload={{self.upload}} /></template>
    );

    assert.dom(".d-icon-far-image").exists();
    assert.dom(".upload-progress[value='78']").exists();
    assert.dom(".uploading").hasText(i18n("uploading"));
  });

  test("image - preprocessing upload in progress", async function (assert) {
    const self = this;

    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
      processing: true,
    });

    await render(
      <template><ChatComposerUpload @upload={{self.upload}} /></template>
    );

    assert.dom(".processing").hasText(i18n("processing"));
  });

  test("file - upload complete", async function (assert) {
    const self = this;

    this.set("upload", {
      type: ".pdf",
      original_filename: "some file.pdf",
      extension: "pdf",
    });

    await render(
      <template>
        <ChatComposerUpload @isDone={{true}} @upload={{self.upload}} />
      </template>
    );

    assert.dom(".d-icon-file-lines").exists();
    assert.dom(".file-name").hasText("some file.pdf");
    assert.dom(".extension-pill").hasText("pdf");
  });

  test("image - upload complete", async function (assert) {
    const self = this;

    this.set("upload", {
      type: ".png",
      original_filename: "bar_image.png",
      extension: "png",
      short_path: "/images/avatar.png",
    });

    await render(
      <template>
        <ChatComposerUpload @isDone={{true}} @upload={{self.upload}} />
      </template>
    );

    assert.dom("img.preview-img[src='/images/avatar.png']").exists();
  });

  test("removing completed upload", async function (assert) {
    const self = this;

    this.set("uploadRemoved", false);
    this.set("removeUpload", () => {
      this.set("uploadRemoved", true);
    });
    this.set("upload", {
      type: ".png",
      original_filename: "bar_image.png",
      extension: "png",
      short_path: "/images/avatar.png",
    });

    await render(
      <template>
        <ChatComposerUpload
          @isDone={{true}}
          @upload={{self.upload}}
          @onCancel={{fn self.removeUpload self.upload}}
        />
      </template>
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });

  test("cancelling in progress upload", async function (assert) {
    const self = this;

    this.set("uploadRemoved", false);
    this.set("removeUpload", () => {
      this.set("uploadRemoved", true);
    });
    this.set("upload", {
      type: ".png",
      original_filename: "bar_image.png",
      extension: "png",
      short_path: "/images/avatar.png",
    });

    await render(
      <template>
        <ChatComposerUpload
          @upload={{self.upload}}
          @onCancel={{fn self.removeUpload self.upload}}
        />
      </template>
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });
});
