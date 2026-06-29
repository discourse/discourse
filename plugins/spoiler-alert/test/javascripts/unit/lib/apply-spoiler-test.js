import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import applySpoiler from "discourse/plugins/spoiler-alert/lib/apply-spoiler";

module("Spoiler Alert | Unit | apply-spoiler", function (hooks) {
  setupTest(hooks);

  function buildSpoiler() {
    const spoiler = document.createElement("div");
    spoiler.classList.add("spoiler");
    spoiler.textContent = "secret";
    return spoiler;
  }

  test("toggles between blurred and revealed on successive clicks", function (assert) {
    const spoiler = buildSpoiler();
    document.body.appendChild(spoiler);

    try {
      applySpoiler(spoiler);
      assert
        .dom(spoiler)
        .hasAttribute("data-spoiler-state", "blurred", "starts blurred");

      spoiler.click();
      assert
        .dom(spoiler)
        .hasAttribute("data-spoiler-state", "revealed", "reveals on click");

      spoiler.click();
      assert
        .dom(spoiler)
        .hasAttribute(
          "data-spoiler-state",
          "blurred",
          "re-blurs on second click"
        );
    } finally {
      spoiler.remove();
    }
  });

  test("can be re-blurred when nested inside a <details> element", function (assert) {
    const details = document.createElement("details");
    details.open = true;
    const summary = document.createElement("summary");
    summary.textContent = "Summary";
    details.appendChild(summary);

    const spoiler = buildSpoiler();
    details.appendChild(spoiler);
    document.body.appendChild(details);

    try {
      applySpoiler(spoiler);
      assert
        .dom(spoiler)
        .hasAttribute("data-spoiler-state", "blurred", "starts blurred");

      spoiler.click();
      assert
        .dom(spoiler)
        .hasAttribute(
          "data-spoiler-state",
          "revealed",
          "reveals on first click"
        );

      spoiler.click();
      assert
        .dom(spoiler)
        .hasAttribute(
          "data-spoiler-state",
          "blurred",
          "re-blurs on second click even though an ancestor <details> exists"
        );
    } finally {
      details.remove();
    }
  });
});
