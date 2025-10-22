import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Assign | Assign disabled mobile (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user({ can_assign: true });
      needs.mobileView();
      needs.settings({
        assign_enabled: false,
        glimmer_post_stream_mode: postStreamMode,
      });

      test("Footer dropdown does not contain button", async function (assert) {
        await visit("/t/internationalization-localization/280");
        assert.dom(".assign").doesNotExist();
      });
    }
  );
});
