import { click, currentURL, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { isLegacyEmber } from "discourse-common/config/environment";

acceptance("Sidebar - Messages Section", function (needs) {
  needs.user({
    experimental_sidebar_enabled: true,
  });

  conditionalTest(
    "clicking on section header button",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      await click(".sidebar-section-messages .sidebar-section-header-button");

      assert.ok(
        exists("#reply-control.private-message"),
        "it opens the composer"
      );
    }
  );

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");
      await click(".sidebar-section-messages .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        `/u/eviltrout/messages`,
        "it should transistion to the user's messages"
      );
    }
  );
});
