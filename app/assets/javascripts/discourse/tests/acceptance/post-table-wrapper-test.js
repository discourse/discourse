import { click, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Post Table Wrapper Test (glimmer_post_stream_mode = ${postStreamMode})`,

    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });

      test("fullscreen table wrapper appears on post with large table", async function (assert) {
        await visit("/t/54081");
        const postWithLargeTable =
          ".post-stream .topic-post[data-post-number='1']";
        assert
          .dom(`${postWithLargeTable} .fullscreen-table-wrapper`)
          .exists("The wrapper is present on the post with the large table");

        assert
          .dom(
            `${postWithLargeTable} .fullscreen-table-wrapper .fullscreen-table-wrapper__buttons .open-popup-link`
          )
          .exists("buttons for the table wrapper appear inside a separate div");

        const fullscreenButtonWrapper = find(
          `${postWithLargeTable} .fullscreen-table-wrapper .fullscreen-table-wrapper__buttons`
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

        assert
          .dom(".fullscreen-table-modal")
          .exists("The fullscreen table modal appears");
        assert
          .dom(".fullscreen-table-modal table")
          .exists("The table is present inside the modal");

        await click(".fullscreen-table-modal .modal-close");
        await click(
          `${postWithLargeTable} .fullscreen-table-wrapper .btn-expand-table svg`
        );

        assert
          .dom(".fullscreen-table-modal")
          .exists("Fullscreen table modal appears on clicking svg icon");
      });
    }
  );
});
