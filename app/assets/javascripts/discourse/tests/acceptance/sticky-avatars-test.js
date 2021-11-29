import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { skip } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Sticky Avatars", function () {
  skip("Adds sticky avatars when scrolling up", async function (assert) {
    const container = document.getElementById("ember-testing-container");
    container.scrollTo(0, 0);

    await visit("/t/internationalization-localization/280");
    container.scrollTo(0, 800);
    container.scrollTo(0, 700);

    // await waitUntil(() => find(".sticky-avatar"));

    assert.ok(
      query("#post_5").parentElement.classList.contains("sticky-avatar"),
      "Sticky avatar is applied"
    );
  });
});
