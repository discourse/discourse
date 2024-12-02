import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from 'discourse-i18n';

module("Discourse Chat | Component | chat-composer-upload", function (hooks) {
  setupRenderingTest(hooks);

  test("file - uploading in progress", async function (assert) {
    this.set("upload", {
      progress: 50,
      extension: ".pdf",
      fileName: "test.pdf",
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.dom(".upload-progress[value='50']").exists();
    assert.dom(".uploading").hasText(i18n("uploading"));
  });

  test("image - uploading in progress", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.dom(".d-icon-far-image").exists();
    assert.dom(".upload-progress[value='78']").exists();
    assert.dom(".uploading").hasText(i18n("uploading"));
  });

  test("image - preprocessing upload in progress", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
      processing: true,
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.dom(".processing").hasText(i18n("processing"));
  });

  test("file - upload complete", async function (assert) {
    this.set("upload", {
      type: ".pdf",
      original_filename: "some file.pdf",
      extension: "pdf",
    });

    await render(
      hbs`<ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />`
    );

    assert.dom(".d-icon-file-lines").exists();
    assert.dom(".file-name").hasText("some file.pdf");
    assert.dom(".extension-pill").hasText("pdf");
  });

  test("image - upload complete", async function (assert) {
    this.set("upload", {
      type: ".png",
      original_filename: "bar_image.png",
      extension: "png",
      short_path: "/images/avatar.png",
    });

    await render(
      hbs`<ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />`
    );

    assert.dom("img.preview-img[src='/images/avatar.png']").exists();
  });

  test("removing completed upload", async function (assert) {
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
      hbs`<ChatComposerUpload @isDone={{true}} @upload={{this.upload}} @onCancel={{fn this.removeUpload this.upload}} />`
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });

  test("cancelling in progress upload", async function (assert) {
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
      hbs`<ChatComposerUpload @upload={{this.upload}} @onCancel={{fn this.removeUpload this.upload}} />`
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });
});
