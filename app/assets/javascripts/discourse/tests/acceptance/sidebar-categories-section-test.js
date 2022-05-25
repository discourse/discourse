import { click, currentURL, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
} from "discourse/tests/helpers/qunit-helpers";
import { isLegacyEmber } from "discourse-common/config/environment";

acceptance("Sidebar - Categories Section", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-categories .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        "/categories",
        "it should transition to the categories page"
      );
    }
  );
});
