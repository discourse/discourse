import { fn } from "@ember/helper";
import { clearRender, click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { restoreBaseUri, setupURL } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
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

  test("image - uploading in progress with local file previews it", async function (assert) {
    this.set("upload", {
      extension: ".png",
      progress: 78,
      fileName: "test.png",
      data: createFile("test.png", "image/png"),
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert.dom(".chat-composer-upload--with-preview").exists();
    assert.dom("img.preview-img").hasAttribute("src", /^blob:/);
    assert.dom(".file-name").doesNotExist();
    assert.dom(".upload-progress[value='78']").exists();
  });

  test("image - revokes the local preview url on teardown", async function (assert) {
    const revoke = sinon.spy(URL, "revokeObjectURL");
    this.set("upload", {
      extension: ".png",
      progress: 10,
      fileName: "test.png",
      data: createFile("test.png", "image/png"),
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    const src = document.querySelector("img.preview-img").getAttribute("src");
    await clearRender();

    assert.true(revoke.calledOnceWith(src));
  });

  test("video - uploading in progress with local file previews it", async function (assert) {
    this.set("upload", {
      extension: ".mp4",
      progress: 20,
      fileName: "clip.mp4",
      data: createFile("clip.mp4", "video/mp4"),
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert
      .dom(".chat-composer-upload--video.chat-composer-upload--with-preview")
      .exists();
    assert.dom("video.preview-video").hasAttribute("src", /^blob:/);
    assert.dom(".preview-video__badge").exists();
    assert.dom(".upload-progress[value='20']").exists();
  });

  test("video - uploading in progress without local file", async function (assert) {
    this.set("upload", {
      extension: ".mp4",
      progress: 20,
      fileName: "clip.mp4",
    });

    await render(
      <template><ChatComposerUpload @upload={{this.upload}} /></template>
    );

    assert.dom(".d-icon-file-video").exists();
    assert.dom(".file-name").hasText("clip.mp4");
  });

  test("video - upload complete", async function (assert) {
    this.set("upload", {
      original_filename: "clip.mp4",
      extension: "mp4",
      url: "/uploads/clip.mp4",
    });

    await render(
      <template>
        <ChatComposerUpload @isDone={{true}} @upload={{this.upload}} />
      </template>
    );

    assert
      .dom("video.preview-video")
      .hasAttribute("src", /^\/uploads\/clip\.mp4/);
    assert.dom(".file-name").doesNotExist();
    assert.dom(".extension-pill").doesNotExist();
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
          @onCancel={{fn this.removeUpload this.upload}}
          @upload={{this.upload}}
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
          @onCancel={{fn this.removeUpload this.upload}}
          @upload={{this.upload}}
        />
      </template>
    );

    await click(".chat-composer-upload__remove-btn");
    assert.true(this.uploadRemoved);
  });
});
