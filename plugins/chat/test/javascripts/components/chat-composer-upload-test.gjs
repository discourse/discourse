import { fn } from "@ember/helper";
import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { restoreBaseUri, setupURL } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatComposerUpload from "discourse/plugins/chat/discourse/components/chat-composer-upload";

module("Component | ChatComposerUpload", function (hooks) {
  setupRenderingTest(hooks);

  test("file - uploading in progress", async function (assert) {
    this.set("upload", {
      progress: 50,
      extension: ".pdf",
      fileName: "test.pdf",
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert.dom(".upload-progress[value='50']").exists();
    assert.dom(".uploading").hasText(i18n("uploading"));
  });

  test("image - uploading in progress", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

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

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert.dom(".processing").hasText(i18n("processing"));
  });

  test("file - upload complete", async function (assert) {
    this.set("upload", {
      type: ".pdf",
      original_filename: "some file.pdf",
      extension: "pdf",
    });

    await render(
      <template>
        <ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />
      </template>
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
      url: "/images/avatar.png",
    });

    await render(
      <template>
        <ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />
      </template>
    );

    assert.dom("img.preview-img[src='/images/avatar.png']").exists();
  });

  test("image - upload complete uses CDN in preview", async function (assert) {
    try {
      setupURL("//cdn.example.com", "http://test.local", "", {
        snapshot: true,
      });

      this.set("upload", {
        type: ".png",
        original_filename: "bar_image.png",
        extension: "png",
        url: "/images/avatar.png",
      });

      await render(
        <template>
          <ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />
        </template>
      );

      assert
        .dom("img.preview-img")
        .hasAttribute("src", "//cdn.example.com/images/avatar.png");
    } finally {
      restoreBaseUri();
    }
  });

  test("audio - uploading in progress", async function (assert) {
    this.set("upload", {
      extension: "weba",
      fileName: "voice-message.weba",
      progress: 60,
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert.dom(".d-icon-file-audio").exists("the audio file icon is shown");
    assert
      .dom(".upload-progress[value='60']")
      .exists("the recording upload progress is shown");
  });

  test("audio - upload complete", async function (assert) {
    this.set("upload", {
      extension: "weba",
      original_filename: "voice-message.weba",
      url: "/uploads/voice-message.weba",
    });

    await render(
      <template>
        <div class="audio-upload-test-container" style="inline-size: 20rem">
          <ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />
        </div>
      </template>
    );

    assert
      .dom(".chat-audio-player")
      .exists("the completed recording can be previewed");
    assert
      .dom(".chat-composer-upload")
      .hasClass("--audio", "the upload uses the audio layout");
    assert
      .dom(".chat-composer-upload .data")
      .doesNotExist("redundant file metadata is omitted");

    const containerRect = find(
      ".audio-upload-test-container"
    ).getBoundingClientRect();
    const uploadRect = find(".chat-composer-upload").getBoundingClientRect();
    const playerRect = find(".chat-audio-player").getBoundingClientRect();

    assert.true(
      uploadRect.width <= containerRect.width,
      "the upload fits its container"
    );
    assert.true(
      playerRect.width <= uploadRect.width,
      "the player fits the upload preview"
    );
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
      <template>
        <ChatComposerUpload
          @isDone={{true}}
          @upload={{this.upload}}
          @onCancel={{fn this.removeUpload this.upload}}
        />
      </template>
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
      <template>
        <ChatComposerUpload
          @upload={{this.upload}}
          @onCancel={{fn this.removeUpload this.upload}}
        />
      </template>
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });
});
