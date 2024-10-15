import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module("Discourse Chat | Component | chat-composer-upload", function (hooks) {
  setupRenderingTest(hooks);

  test("file - uploading in progress", async function (assert) {
    this.set("upload", {
      progress: 50,
      extension: ".pdf",
      fileName: "test.pdf",
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.true(exists(".upload-progress[value=50]"));
    assert.dom(".uploading").hasText(I18n.t("uploading"));
  });

  test("image - uploading in progress", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.true(exists(".d-icon-far-image"));
    assert.true(exists(".upload-progress[value=78]"));
    assert.dom(".uploading").hasText(I18n.t("uploading"));
  });

  test("image - preprocessing upload in progress", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
      processing: true,
    });

    await render(hbs`<ChatComposerUpload @upload={{this.upload}} />`);

    assert.dom(".processing").hasText(I18n.t("processing"));
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

    assert.true(exists(".d-icon-file-lines"));
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

    assert.true(exists("img.preview-img[src='/images/avatar.png']"));
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
    assert.strictEqual(this.uploadRemoved, true);
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
    assert.strictEqual(this.uploadRemoved, true);
  });
});
