import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupS3CDN } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatUpload from "discourse/plugins/chat/discourse/components/chat-upload";

const IMAGE_FIXTURE = {
  id: 290,
  url: null, // Nulled out to avoid actually setting the img src - avoids an HTTP request
  original_filename: "image.jpg",
  filesize: 172214,
  width: 1024,
  height: 768,
  thumbnail_width: 666,
  thumbnail_height: 500,
  extension: "jpeg",
  short_url: "upload://mnCnqY5tunCFw2qMgtPnu1mu1C9.jpeg",
  short_path: "/uploads/short-url/mnCnqY5tunCFw2qMgtPnu1mu1C9.jpeg",
  retain_hours: null,
  human_filesize: "168 KB",
  dominant_color: "788370", // rgb(120, 131, 112)
};

const VIDEO_FIXTURE = {
  id: 290,
  url: null, // Nulled out to avoid actually setting the src - avoids an HTTP request
  original_filename: "video.mp4",
  filesize: 172214,
  width: 1024,
  height: 768,
  thumbnail_width: 666,
  thumbnail_height: 500,
  extension: "mp4",
  short_url: "upload://mnCnqY5tunCFw2qMgtPnu1mu1C9.mp4",
  short_path: "/uploads/short-url/mnCnqY5tunCFw2qMgtPnu1mu1C9.mp4",
  retain_hours: null,
  human_filesize: "168 KB",
};

const AUDIO_FIXTURE = {
  id: 290,
  url: null, // Nulled out to avoid actually setting the src - avoids an HTTP request
  original_filename: "song.mp3",
  filesize: 172214,
  width: 1024,
  height: 768,
  thumbnail_width: 666,
  thumbnail_height: 500,
  extension: "mp3",
  short_url: "upload://mnCnqY5tunCFw2qMgtPnu1mu1C9.mp3",
  short_path: "/uploads/short-url/mnCnqY5tunCFw2qMgtPnu1mu1C9.mp3",
  retain_hours: null,
  human_filesize: "168 KB",
};

const TXT_FIXTURE = {
  id: 290,
  url: "https://example.com/file.txt",
  original_filename: "file.txt",
  filesize: 172214,
  extension: "txt",
  short_url: "upload://mnCnqY5tunCFw2qMgtPnu1mu1C9.jpeg",
  short_path: "/uploads/short-url/mnCnqY5tunCFw2qMgtPnu1mu1C9.jpeg",
  retain_hours: null,
  human_filesize: "168 KB",
};

class MockCapabilitiesService extends Service {
  @tracked isIOS = false;
  @tracked isSafari = false;
}

module("Component | ChatUpload", function (hooks) {
  setupRenderingTest(hooks);

  test("with an image", async function (assert) {
    this.set("upload", IMAGE_FIXTURE);

    await render(<template><ChatUpload @upload={{this.upload}} /></template>);

    assert.dom("img.chat-img-upload").exists("displays as an image");
    assert
      .dom("img.chat-img-upload")
      .hasProperty("loading", "lazy", "is lazy loading");

    assert
      .dom("img.chat-img-upload")
      .hasStyle(
        { backgroundColor: "rgb(120, 131, 112)" },
        "sets background to dominant color"
      );

    await triggerEvent("img.chat-img-upload", "load"); // Fake that the image has loaded

    assert
      .dom("img.chat-img-upload")
      .doesNotHaveStyle(
        "backgroundColor",
        "removes the background color once the image has loaded"
      );
  });

  test("with a video", async function (assert) {
    this.set("upload", VIDEO_FIXTURE);

    await render(<template><ChatUpload @upload={{this.upload}} /></template>);

    assert.dom("video.chat-video-upload").exists("displays as an video");
    assert.dom("video.chat-video-upload").hasAttribute("controls");
    assert
      .dom("video.chat-video-upload")
      .hasAttribute(
        "preload",
        "metadata",
        "video has correct preload settings"
      );
  });

  test("with a audio", async function (assert) {
    this.set("upload", AUDIO_FIXTURE);

    await render(<template><ChatUpload @upload={{this.upload}} /></template>);

    assert.dom("audio.chat-audio-upload").exists("displays as an audio");
    assert.dom("audio.chat-audio-upload").hasAttribute("controls");
    assert
      .dom("audio.chat-audio-upload")
      .hasAttribute(
        "preload",
        "metadata",
        "audio has correct preload settings"
      );
  });

  test("non image upload", async function (assert) {
    this.set("upload", TXT_FIXTURE);

    await render(<template><ChatUpload @upload={{this.upload}} /></template>);

    assert.dom("a.chat-other-upload").exists("displays as a link");
    assert
      .dom("a.chat-other-upload")
      .hasAttribute("href", TXT_FIXTURE.url, "has the correct URL");
  });

  module("S3 CDN URLs", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.owner.unregister("service:capabilities");
      this.owner.register("service:capabilities", MockCapabilitiesService);

      setupS3CDN(
        "//test.s3-us-west-1.amazonaws.com/site",
        "https://awesome.cdn/site"
      );
    });

    test("uses the CDN for image src and data-large-src", async function (assert) {
      this.set("upload", {
        ...IMAGE_FIXTURE,
        url: "https://test.s3-us-west-1.amazonaws.com/site/original.jpg",
        thumbnail: {
          url: "https://test.s3-us-west-1.amazonaws.com/site/thumbnail.jpg",
        },
      });

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("img.chat-img-upload")
        .hasAttribute(
          "src",
          "https://awesome.cdn/site/thumbnail.jpg",
          "uses the CDN for image thumbnails"
        );
      assert
        .dom("img.chat-img-upload")
        .hasAttribute(
          "data-large-src",
          "https://awesome.cdn/site/original.jpg",
          "uses the CDN for the full-size image URL"
        );
    });

    test("uses the CDN for video sources", async function (assert) {
      this.set("upload", {
        ...VIDEO_FIXTURE,
        url: "https://test.s3-us-west-1.amazonaws.com/site/video.mp4",
      });

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("video.chat-video-upload source")
        .hasAttribute(
          "src",
          "https://awesome.cdn/site/video.mp4",
          "uses the CDN for video uploads"
        );
    });

    test("uses the CDN for audio sources", async function (assert) {
      this.set("upload", {
        ...AUDIO_FIXTURE,
        url: "https://test.s3-us-west-1.amazonaws.com/site/song.mp3",
      });

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("audio.chat-audio-upload source")
        .hasAttribute(
          "src",
          "https://awesome.cdn/site/song.mp3",
          "uses the CDN for audio uploads"
        );
    });

    test("uses the CDN for attachment hrefs", async function (assert) {
      this.set("upload", {
        ...TXT_FIXTURE,
        url: "https://test.s3-us-west-1.amazonaws.com/site/file.txt",
      });

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("a.chat-other-upload")
        .hasAttribute(
          "href",
          "https://awesome.cdn/site/file.txt",
          "uses the CDN for attachment uploads"
        );
    });
  });

  module("video source URL", function (nestedHooks) {
    let mockCapabilities;

    nestedHooks.beforeEach(function () {
      this.owner.unregister("service:capabilities");
      this.owner.register("service:capabilities", MockCapabilitiesService);
      mockCapabilities = this.owner.lookup("service:capabilities");
    });

    test("adds timestamp parameter for Safari", async function (assert) {
      this.set("upload", {
        ...VIDEO_FIXTURE,
        url: "https://example.com/video.mp4",
      });
      mockCapabilities.isSafari = true;

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("video.chat-video-upload source")
        .hasAttribute(
          "src",
          "https://example.com/video.mp4#t=0.001",
          "adds timestamp for Safari"
        );
    });

    test("does not add timestamp parameter for other browsers", async function (assert) {
      this.set("upload", {
        ...VIDEO_FIXTURE,
        url: "https://example.com/video.mp4",
      });
      mockCapabilities.isSafari = false;

      await render(<template><ChatUpload @upload={{this.upload}} /></template>);

      assert
        .dom("video.chat-video-upload source")
        .hasAttribute(
          "src",
          "https://example.com/video.mp4",
          "does not add timestamp for other browsers"
        );
    });
  });
});
