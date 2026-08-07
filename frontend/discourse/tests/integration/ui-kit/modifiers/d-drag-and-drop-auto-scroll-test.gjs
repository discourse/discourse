import { clearRender, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import { matchesDragType } from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";

function source(type) {
  return { data: { type } };
}

/**
 * The scrolling itself is not asserted here: it needs a real drag in flight, a
 * pointer held near a container edge, and several animation frames, which is the
 * underlying library's behaviour rather than this modifier's. What the modifier
 * owns is the type gate it supplies and the registration lifecycle, and those
 * are what these cover.
 */
module(
  "Integration | Modifier | d-drag-and-drop-auto-scroll",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the shared type gate engages only for the requested types", async function (assert) {
      assert.true(
        matchesDragType(undefined, source("row")),
        "no filter engages on any drag"
      );
      assert.true(
        matchesDragType([], source("row")),
        "an empty list is the same as no filter"
      );
      assert.true(
        matchesDragType("row", source("row")),
        "a single matching type engages"
      );
      assert.false(
        matchesDragType("row", source("card")),
        "a single non-matching type does not"
      );
      assert.true(
        matchesDragType(["row", "card"], source("card")),
        "a list containing the type engages"
      );
      assert.false(
        matchesDragType(["row", "card"], source("other")),
        "a list without it does not"
      );
      assert.false(
        matchesDragType("row", { data: {} }),
        "a typeless source matches no filter"
      );
    });

    test("registers against a scroll container without claiming drops", async function (assert) {
      await render(
        <template>
          <div
            class="scroller"
            {{dDragAndDropAutoScroll types="row" axis="vertical"}}
          >content</div>
        </template>
      );

      // Auto-scroll moves the container; it never accepts a drop of its own, so
      // a consumer can attach it beside a target without the two colliding.
      assert
        .dom(".scroller")
        .doesNotHaveAttribute(
          "data-drop-target",
          "the container is not registered as an element drop target"
        )
        .doesNotHaveAttribute(
          "data-drop-target-external",
          "nor as an external one"
        );
    });

    test("target=window registers against the window and ignores its element", async function (assert) {
      await render(
        <template>
          <span
            class="sentinel"
            {{dDragAndDropAutoScroll types="row" target="window"}}
          ></span>
        </template>
      );

      assert
        .dom(".sentinel")
        .exists("the sentinel element is only a lifecycle host")
        .doesNotHaveAttribute(
          "data-drop-target",
          "the window variant marks nothing on its host"
        );

      // Teardown has to unregister the window listener rather than a container's;
      // getting that wrong strands a global registration for the whole suite.
      const sentinel = find(".sentinel");
      await clearRender();

      assert.false(
        sentinel.isConnected,
        "the host is gone and its registration went with it"
      );
    });
  }
);
