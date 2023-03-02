import { render, waitFor } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module(
  "Discourse Chat | Modifier | track-message-visibility",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Marks message as visible when it intersects with the viewport", async function (assert) {
      const template = hbs`<div {{chat/track-message-visibility}}></div>`;

      await render(template);
      await waitFor("div[data-visible=true]");

      assert.ok(
        exists("div[data-visible=true]"),
        "message is marked as visible"
      );
    });

    test("Marks message as visible when it doesn't intersect with the viewport", async function (assert) {
      const template = hbs`<div style="display:none;" {{chat/track-message-visibility}}></div>`;

      await render(template);
      await waitFor("div[data-visible=false]");

      assert.ok(
        exists("div[data-visible=false]"),
        "message is not marked as visible"
      );
    });
  }
);
