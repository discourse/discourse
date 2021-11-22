import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { find, scrollTo, visit, waitUntil } from "@ember/test-helpers";
import { setupApplicationTest as EMBER_CLI_ENV } from "ember-qunit";

acceptance("Sticky Avatars", function (needs) {
  if (!EMBER_CLI_ENV) {
    return; // helpers not available in legacy env
  }

  const container = document.getElementById("ember-testing-container");
  needs.user();
  needs.hooks.beforeEach(function () {
    container.scrollTop = 0;
  });

  test("Adds sticky avatars when scrolling up", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const appEvents = loggedInUser().appEvents;
    await scrollTo(container, 0, 800);
    appEvents.trigger("topic:scrolled", 800);
    await scrollTo(container, 0, 700);
    appEvents.trigger("topic:scrolled", 700);

    await waitUntil(() => find(".sticky-avatar"));
    assert.ok(
      find("#post_5").parentElement.classList.contains("sticky-avatar"),
      "Sticky avatar is applied"
    );
  });
});
