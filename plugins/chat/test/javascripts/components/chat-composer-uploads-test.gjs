import {
  click,
  render,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { PNG_BYTES, WEBM_BYTES } from "discourse/tests/helpers/media-fixtures";
import {
  createFile,
  silenceConsoleErrorsMatching,
} from "discourse/tests/helpers/qunit-helpers";
import ChatComposerUploads from "discourse/plugins/chat/discourse/components/chat-composer-uploads";

const fakeUpload = {
  type: ".png",
  extension: "png",
  name: "myfile.png",
  short_path: "/images/avatar.png",
};

const mockUploadResponse = {
  extension: "jpeg",
  filesize: 126177,
  height: 800,
  human_filesize: "123 KB",
  id: 202,
  original_filename: "avatar.PNG.jpg",
  retain_hours: null,
  short_path: "/images/avatar.png",
  short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
  thumbnail_height: 320,
  thumbnail_width: 690,
  url: "/images/avatar.png",
  width: 1920,
};

function setupUploadPretender() {
  pretender.post(
    "/uploads.json",
    () => {
      return [200, { "Content-Type": "application/json" }, mockUploadResponse];
    },
    500 // this delay is important to slow down the uploads a bit so we can click elements in the UI like the cancel button
  );
}

module("Component | ChatComposerUploads", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(async function () {
    if (document.querySelector(".pswp")) {
      await triggerKeyEvent(".pswp", "keydown", "Escape");
      await waitUntil(() => !document.querySelector(".pswp"));
    }
  });

  test("opens previewed uploads in a lightbox from the clicked one", async function (assert) {
    // decodable media, so only the broken image falls back to the icon
    const videoUrl = URL.createObjectURL(
      new Blob([WEBM_BYTES], { type: "video/webm" })
    );
    const brokenImageUrl = URL.createObjectURL(
      new Blob(["not an image"], { type: "image/png" })
    );
    this.existingUploads = [
      {
        original_filename: "photo.png",
        extension: "png",
        url: "/images/avatar.png",
      },
      {
        original_filename: "broken.png",
        extension: "png",
        url: brokenImageUrl,
      },
      { original_filename: "clip.webm", extension: "webm", url: videoUrl },
    ];

    try {
      await render(
        <template>
          <ChatComposerUploads
            @existingUploads={{this.existingUploads}}
            @fileUploadElementId="chat-widget-uploader"
          />
        </template>
      );
      await waitUntil(
        () =>
          document.querySelectorAll(".chat-composer-upload__preview-btn")
            .length === 2
      );

      await click(
        ".chat-composer-upload--video .chat-composer-upload__preview-btn"
      );
      await waitFor(".pswp--open");

      assert
        .dom(".pswp__counter", document.body)
        .hasText("2 / 2", "skips the broken image and opens at the video");
      assert
        .dom(
          ".pswp__item[aria-hidden='false'] video.pswp__video",
          document.body
        )
        .hasAttribute("src", new RegExp(`^${videoUrl}`));
      assert.dom(".pswp__caption-title", document.body).hasText("clip.webm");
    } finally {
      URL.revokeObjectURL(videoUrl);
      URL.revokeObjectURL(brokenImageUrl);
    }
  });

  test("an upload that finishes keeps its slide while the lightbox is open", async function (assert) {
    setupUploadPretender();
    const revoke = sinon.spy(URL, "revokeObjectURL");

    await render(
      <template>
        <ChatComposerUploads @fileUploadElementId="chat-widget-uploader" />
      </template>
    );

    this.container
      .lookup("service:app-events")
      .trigger(
        "upload-mixin:chat-composer-uploader:add-files",
        createFile("avatar.png", "image/png", PNG_BYTES)
      );
    await waitFor(".chat-composer-upload--in-progress .preview-img");
    const tileUrl = document
      .querySelector(".chat-composer-upload--in-progress .preview-img")
      .getAttribute("src");

    await click(
      ".chat-composer-upload--in-progress .chat-composer-upload__preview-btn"
    );
    await waitFor(".pswp--open");
    const slideUrl = window.pswp.currSlide.data.src;
    assert.true(slideUrl.startsWith("blob:"), "shows the unfinished file");
    assert.notStrictEqual(slideUrl, tileUrl, "uses its own link to it");

    await waitFor(
      ".chat-composer-upload:not(.chat-composer-upload--in-progress)",
      {
        timeout: 5000,
      }
    );
    assert.true(
      revoke.calledWith(tileUrl),
      "the finished tile releases its link"
    );
    assert.false(revoke.calledWith(slideUrl), "the lightbox keeps its own");

    await triggerKeyEvent(".pswp", "keydown", "Escape");
    await waitUntil(() => revoke.calledWith(slideUrl));
    assert.true(
      revoke.calledWith(slideUrl),
      "released once the lightbox closes"
    );
  });

  test("loading uploads from an outside source (e.g. draft or editing message)", async function (assert) {
    this.existingUploads = [fakeUpload];

    await render(
      <template>
        <ChatComposerUploads
          @existingUploads={{this.existingUploads}}
          @fileUploadElementId="chat-widget-uploader"
        />
      </template>
    );

    assert.dom(".chat-composer-upload").exists({ count: 1 });
  });

  test("upload starts and completes", async function (assert) {
    setupUploadPretender();
    this.set("onUploadChanged", () => {});

    await render(
      <template>
        <ChatComposerUploads
          @fileUploadElementId="chat-widget-uploader"
          @onUploadChanged={{this.onUploadChanged}}
        />
      </template>
    );

    const done = assert.async();
    this.appEvents = this.container.lookup("service:app-events");
    this.appEvents.on(
      "upload-mixin:chat-composer-uploader:upload-success",
      (fileName, upload) => {
        assert.strictEqual(fileName, "avatar.png");
        assert.deepEqual(upload, mockUploadResponse);
        done();
      }
    );
    this.appEvents.trigger(
      "upload-mixin:chat-composer-uploader:add-files",
      createFile("avatar.png")
    );

    await waitFor(".chat-composer-upload");

    assert.dom(".chat-composer-upload").exists({ count: 1 });
  });

  test("removing a completed upload", async function (assert) {
    this.set("changedUploads", null);
    this.set("onUploadChanged", () => {});

    this.existingUploads = [fakeUpload];

    await render(
      <template>
        <ChatComposerUploads
          @existingUploads={{this.existingUploads}}
          @fileUploadElementId="chat-widget-uploader"
          @onUploadChanged={{this.onUploadChanged}}
        />
      </template>
    );

    assert.dom(".chat-composer-upload").exists({ count: 1 });

    await click(".chat-composer-upload__remove-btn");

    assert.dom(".chat-composer-upload").exists({ count: 0 });
  });

  test("cancelling in progress upload", async function (assert) {
    silenceConsoleErrorsMatching("[Uppy]");
    setupUploadPretender();

    this.set("changedUploads", null);
    this.set("onUploadChanged", (uploads) => {
      this.set("changedUploads", uploads);
    });

    await render(
      <template>
        <ChatComposerUploads
          @fileUploadElementId="chat-widget-uploader"
          @onUploadChanged={{this.onUploadChanged}}
        />
      </template>
    );

    const image = createFile("avatar.png");
    const done = assert.async();
    this.appEvents = this.container.lookup("service:app-events");

    this.appEvents.on(
      `upload-mixin:chat-composer-uploader:upload-cancelled`,
      (fileId) => {
        assert.true(
          fileId.includes("chat-composer-uploader-avatar/"),
          "upload was cancelled"
        );
        done();
      }
    );

    this.appEvents.trigger(
      "upload-mixin:chat-composer-uploader:add-files",
      image
    );

    await waitFor(".chat-composer-upload");
    assert.dom(".chat-composer-upload").exists({ count: 1 });

    await click(".chat-composer-upload__remove-btn");
    assert.dom(".chat-composer-upload").doesNotExist();
  });
});
