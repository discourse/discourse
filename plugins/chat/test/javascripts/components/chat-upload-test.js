import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module } from "qunit";
import { settled } from "@ember/test-helpers";

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
  url: null, // Nulled out to avoid actually setting the img src - avoids an HTTP request
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

module("Discourse Chat | Component | chat-upload", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("with an image", {
    template: hbs`{{chat-upload upload=upload}}`,

    beforeEach() {
      this.set("upload", IMAGE_FIXTURE);
    },

    async test(assert) {
      assert.true(exists("img.chat-img-upload"), "displays as an image");
      const image = query("img.chat-img-upload");
      assert.strictEqual(image.loading, "lazy", "is lazy loading");

      assert.strictEqual(
        image.style.backgroundColor,
        "rgb(120, 131, 112)",
        "sets background to dominant color"
      );

      image.dispatchEvent(new Event("load")); // Fake that the image has loaded
      await settled();

      assert.strictEqual(
        image.style.backgroundColor,
        "",
        "removes the background color once the image has loaded"
      );
    },
  });

  componentTest("with a video", {
    template: hbs`{{chat-upload upload=upload}}`,

    beforeEach() {
      this.set("upload", VIDEO_FIXTURE);
    },

    async test(assert) {
      assert.true(exists("video.chat-video-upload"), "displays as an video");
      const video = query("video.chat-video-upload");
      assert.ok(video.hasAttribute("controls"), "has video controls");
      assert.strictEqual(
        video.getAttribute("preload"),
        "metadata",
        "video has correct preload settings"
      );
    },
  });

  componentTest("non image upload", {
    template: hbs`{{chat-upload upload=upload}}`,

    beforeEach() {
      this.set("upload", TXT_FIXTURE);
    },

    async test(assert) {
      assert.true(exists("a.chat-other-upload"), "displays as a link");
      const link = query("a.chat-other-upload");
      assert.strictEqual(link.href, TXT_FIXTURE.url, "has the correct URL");
    },
  });
});
