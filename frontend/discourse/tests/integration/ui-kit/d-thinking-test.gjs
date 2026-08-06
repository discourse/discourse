import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DThinking from "discourse/ui-kit/d-thinking";

module("Integration | ui-kit | DThinking", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a canvas by default", async function (assert) {
    await render(<template><DThinking /></template>);

    assert.dom("canvas.d-thinking.d-thinking--large").exists();
    assert.dom("canvas.d-thinking").hasAttribute("aria-label", "Thinking…");
  });

  test("renders an svg ring when small", async function (assert) {
    await render(<template><DThinking @size="small" /></template>);

    assert.dom("svg.d-thinking.d-thinking--small").exists();
    assert
      .dom("svg.d-thinking")
      .hasAttribute("viewBox", "0 0 20 20")
      .hasAttribute("aria-label", "Thinking…");
    assert.dom("svg.d-thinking circle").exists({ count: 22 });
  });

  test("accepts a custom label", async function (assert) {
    await render(<template><DThinking @label="Summarizing…" /></template>);

    assert.dom("canvas.d-thinking").hasAttribute("aria-label", "Summarizing…");
  });

  test("renders the lava variant", async function (assert) {
    await render(<template><DThinking @type="lava" @size="small" /></template>);

    assert.dom("svg.d-thinking.d-thinking--lava").exists();
    assert.dom("svg.d-thinking rect").exists({ count: 2 });
    assert.dom("svg.d-thinking circle").exists({ count: 3 });
  });

  test("renders the ribbons variant", async function (assert) {
    await render(
      <template><DThinking @type="ribbons" @size="small" /></template>
    );

    assert.dom("svg.d-thinking.d-thinking--ribbons").exists();
    assert.dom("svg.d-thinking path").exists({ count: 5 });
  });

  test("falls back to breathing for unknown types", async function (assert) {
    await render(
      <template><DThinking @type="disco" @size="small" /></template>
    );

    assert.dom("svg.d-thinking.d-thinking--breathing").exists();
    assert.dom("svg.d-thinking circle").exists({ count: 22 });
  });
});
