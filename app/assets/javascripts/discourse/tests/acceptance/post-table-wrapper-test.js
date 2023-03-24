import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Post Table Wrapper Test", function () {
  test("fullscreen table wrapper appears on post with large table", async function (assert) {
    await visit("/t/54081");
    const postWithLargeTable = ".post-stream .topic-post:first-child";
    assert.ok(
      exists(`${postWithLargeTable} .fullscreen-table-wrapper`),
      "The wrapper is present on the post with the large table"
    );

    assert.ok(
      exists(
        `${postWithLargeTable} .fullscreen-table-wrapper .fullscreen-table-wrapper--buttons .open-popup-link`
      ),
      "buttons for the table wrapper appear inside a separate div"
    );

    const fullscreenButtonWrapper = query(
      `${postWithLargeTable} .fullscreen-table-wrapper .fullscreen-table-wrapper--buttons`
    );

    assert.strictEqual(
      window
        .getComputedStyle(fullscreenButtonWrapper)
        .getPropertyValue("position"),
      "absolute",
      "the wrapper buttons should not be in the cooked post's flow"
    );

    await click(
      `${postWithLargeTable} .fullscreen-table-wrapper .btn-expand-table`
    );
    assert.ok(
      exists(".fullscreen-table-modal"),
      "The fullscreen table modal appears"
    );
    assert.ok(
      exists(".fullscreen-table-modal table"),
      "The table is present inside the modal"
    );
  });
});
