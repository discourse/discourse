import { click, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer preview sizing", function (needs) {
  needs.user({
    "user_option.composition_mode": USER_OPTION_COMPOSITION_MODES.markdown,
  });
  needs.settings({ allow_uncategorized_topics: true });

  test("markdown has its final preview width before the first opening", async function (assert) {
    await visit("/");
    this.owner.lookup("service:composer").showPreview = true;
    await settled();

    assert
      .dom("#reply-control")
      .hasClass("closed", "the composer starts closed");
    assert
      .dom("#reply-control")
      .hasClass("show-preview", "preview width is reserved before opening");
    const initialMaxWidth = getComputedStyle(find("#reply-control")).maxWidth;

    await click("#create-topic");

    assert.dom("#reply-control").hasClass("open", "the composer opens");
    assert
      .dom("#reply-control")
      .hasClass(
        "show-preview",
        "the mounted editor keeps the predicted preview"
      );
    assert.strictEqual(
      getComputedStyle(find("#reply-control")).maxWidth,
      initialMaxWidth,
      "opening does not change the width target or trigger horizontal expansion"
    );
  });

  test("a hidden markdown preview keeps the composer narrow before opening", async function (assert) {
    await visit("/");
    this.owner.lookup("service:composer").showPreview = false;
    await settled();

    assert
      .dom("#reply-control")
      .hasClass(
        "hide-preview",
        "the closed composer respects the preview preference"
      );
    const initialMaxWidth = getComputedStyle(find("#reply-control")).maxWidth;

    await click("#create-topic");

    assert
      .dom("#reply-control")
      .hasClass("hide-preview", "the preview stays hidden after opening");
    assert.strictEqual(
      getComputedStyle(find("#reply-control")).maxWidth,
      initialMaxWidth,
      "opening without preview does not change the width target"
    );
  });
});
