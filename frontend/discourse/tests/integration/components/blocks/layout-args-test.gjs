import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

@block("layout-args-test-a")
class BlockA extends Component {
  <template>
    <div class="marker-a">A</div>
  </template>
}

@block("layout-args-test-b")
class BlockB extends Component {
  <template>
    <div class="marker-b">B</div>
  </template>
}

function layoutStyle() {
  return document.querySelector(".d-block-layout").getAttribute("style") ?? "";
}

function renderLayout(api, args) {
  api.renderBlocks("hero-blocks", [
    {
      block: Layout,
      args,
      children: [{ block: BlockA }, { block: BlockB }],
    },
  ]);
}

module("Integration | Blocks | builtin | layout args", function (hooks) {
  setupRenderingTest(hooks);

  test("flex modes wrap children in `.d-block-layout__flex`; grid does not", async function (assert) {
    withPluginApi((api) => renderLayout(api, { mode: "row" }));
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-layout__flex")
      .exists("a row layout holds its children in the flex wrapper");
    assert
      .dom(".d-block-layout__flex .marker-a")
      .exists("children render inside the flex wrapper");
  });

  test("grid mode uses cells, not the flex wrapper", async function (assert) {
    withPluginApi((api) => renderLayout(api, { mode: "grid", columns: 2 }));
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-layout__flex")
      .doesNotExist("grid mode does not render the flex wrapper");
    assert.dom(".d-block-layout__cell").exists({ count: 2 });
  });

  test("row emits justify-content + wrap; stack omits wrap", async function (assert) {
    withPluginApi((api) =>
      renderLayout(api, {
        mode: "row",
        justifyContent: "space-between",
        wrap: "nowrap",
      })
    );
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const style = layoutStyle();
    assert.true(
      style.includes("--d-block-layout-justify-content: space-between"),
      "justify-content custom prop is emitted"
    );
    assert.true(
      style.includes("--d-block-layout-wrap: nowrap"),
      "row emits the wrap custom prop"
    );
  });

  test("stack does not emit the wrap custom prop", async function (assert) {
    withPluginApi((api) => renderLayout(api, { mode: "stack" }));
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.false(
      layoutStyle().includes("--d-block-layout-wrap"),
      "stack stays at the implicit nowrap (no wrap var)"
    );
  });

  test("grid emits justify-content / justify-items / align-content / auto-flow", async function (assert) {
    withPluginApi((api) =>
      renderLayout(api, {
        mode: "grid",
        columns: 2,
        justifyContent: "center",
        justifyItems: "end",
        alignContent: "space-around",
        dense: true,
      })
    );
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const style = layoutStyle();
    assert.true(style.includes("--d-block-layout-justify-content: center"));
    assert.true(style.includes("--d-block-layout-justify-items: end"));
    assert.true(style.includes("--d-block-layout-align-content: space-around"));
    assert.true(
      style.includes("--d-block-layout-auto-flow: row dense"),
      "dense toggles `grid-auto-flow: row dense`"
    );
  });

  test("non-dense grid emits a plain `row` auto-flow", async function (assert) {
    withPluginApi((api) => renderLayout(api, { mode: "grid", columns: 2 }));
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.true(layoutStyle().includes("--d-block-layout-auto-flow: row;"));
  });

  test("reverse reverses rendered child order for a row", async function (assert) {
    withPluginApi((api) => renderLayout(api, { mode: "row", reverse: true }));
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const markers = [
      ...document.querySelectorAll(
        ".d-block-layout__flex .marker-a, .d-block-layout__flex .marker-b"
      ),
    ].map((el) => el.textContent.trim());
    assert.deepEqual(markers, ["B", "A"], "the DOM order is reversed");
  });

  test("reverse does NOT reorder a grid (placement sort wins)", async function (assert) {
    withPluginApi((api) =>
      renderLayout(api, { mode: "grid", columns: 2, reverse: true })
    );
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const markers = [...document.querySelectorAll(".marker-a, .marker-b")].map(
      (el) => el.textContent.trim()
    );
    assert.deepEqual(markers, ["A", "B"], "grid keeps its placement order");
  });
});
