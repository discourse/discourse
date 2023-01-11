import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Image aspect ratio", function () {
  test("it applies the aspect ratio", async function (assert) {
    await visit("/t/2480");
    const image = query("#post_3 img[src='/assets/logo.png']");

    assert.strictEqual(image.style.aspectRatio, "690 / 388");
  });
});
