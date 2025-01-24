import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Image aspect ratio", function () {
  test("applies the aspect ratio", async function (assert) {
    await visit("/t/2480");

    assert
      .dom("#post_3 img[src='/assets/logo.png']")
      .hasStyle({ aspectRatio: "690 / 388" });
  });
});
