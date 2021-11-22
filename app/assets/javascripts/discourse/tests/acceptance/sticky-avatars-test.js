import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { find, visit, waitUntil } from "@ember/test-helpers";
import { setupApplicationTest as EMBER_CLI_ENV } from "ember-qunit";
import { later } from "@ember/runloop";

acceptance("Sticky Avatars", function (needs) {
  if (!EMBER_CLI_ENV) {
    return; // helpers not available in legacy env
  }

  needs.user();
  needs.hooks.beforeEach(function () {
    window.scrollTop = 0;
  });

  test("Adds sticky avatars when scrolling up", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await window.scroll(0, 2050);
    // delay necessary because scroll events are debounced
    await later(() => window.scroll(0, 1900), 200);

    await waitUntil(() => find(".sticky-avatar"));
    assert.ok(
      find("#post_5").parentElement.classList.contains("sticky-avatar"),
      "Sticky avatar is applied"
    );
  });
});
