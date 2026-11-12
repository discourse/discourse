import { module, test } from "qunit";
import { imageBase62Sha1 } from "discourse/plugins/discourse-ai/discourse/lib/post-image-caption-editor";

module("Unit | Lib | post-image-caption-editor", function () {
  test("imageBase62Sha1 reads data-base62-sha1", function (assert) {
    const image = document.createElement("img");
    image.dataset.base62Sha1 = "abc123XYZ";

    assert.strictEqual(imageBase62Sha1(image), "abc123XYZ");
  });

  test("imageBase62Sha1 falls back to upload short URLs", function (assert) {
    const image = document.createElement("img");
    image.setAttribute("data-orig-src", "upload://abc123XYZ.png");

    assert.strictEqual(imageBase62Sha1(image), "abc123XYZ");
  });

  test("imageBase62Sha1 falls back to resolved upload URLs", function (assert) {
    const image = document.createElement("img");
    image.setAttribute(
      "src",
      "/uploads/default/original/1X/0049585045f353bed81bb257092d58b968539ff6.jpeg"
    );

    assert.strictEqual(imageBase62Sha1(image), "2x8JyApqlboI0dAsfwbPbZ7Ho2");
  });

  test("imageBase62Sha1 ignores invalid values", function (assert) {
    const image = document.createElement("img");
    image.dataset.base62Sha1 = "../bad";
    image.dataset.origSrc = "https://example.com/image.png";

    assert.strictEqual(imageBase62Sha1(image), undefined);
  });
});
