import { module, test } from "qunit";
import { render, triggerEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";
import { query } from "discourse/tests/helpers/qunit-helpers";

async function mouseenter() {
  await triggerEvent(query("button"), "mouseenter");
}

module("Integration | Component | d-tooltip", function (hooks) {
  setupRenderingTest(hooks);

  test("doesn't show tooltip if it wasn't expanded", async function (assert) {
    await render(hbs`
      <button>
        <DTooltip>
          Tooltip text
        </DTooltip>
      </button>
     `);
    assert.notOk(document.querySelector("[data-tippy-root]"));
  });

  test("it shows tooltip on mouseenter", async function (assert) {
    await render(hbs`
      <button>
        <DTooltip>
          Tooltip text
        </DTooltip>
      </button>
     `);

    await mouseenter();
    assert.ok(
      document.querySelector("[data-tippy-root]"),
      "the tooltip is added to the page"
    );
    assert.equal(
      document
        .querySelector("[data-tippy-root] .tippy-content")
        .textContent.trim(),
      "Tooltip text",
      "the tooltip content is correct"
    );
  });
});
