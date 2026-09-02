import { tracked } from "@glimmer/tracking";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dScrollEdges from "discourse/ui-kit/modifiers/d-scroll-edges";

function nextFrame() {
  return new Promise((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))
  );
}

module("Integration | ui-kit | Modifier | dScrollEdges", function (hooks) {
  setupRenderingTest(hooks);

  test("marks an overflowing horizontal strip and tracks which edge it rests on", async function (assert) {
    await render(
      <template>
        <div
          class="strip"
          style="width: 100px; overflow-x: auto; white-space: nowrap"
          {{dScrollEdges}}
        >
          <span style="display: inline-block; width: 300px">wide</span>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".strip")
      .hasAttribute("data-d-scroll-overflow", "", "the strip overflows");
    assert
      .dom(".strip")
      .hasAttribute(
        "data-d-scroll-axis",
        "horizontal",
        "the strip reports its horizontal axis"
      );
    assert
      .dom(".strip")
      .hasAttribute("data-d-scroll-at-start", "", "it rests at its start");
    assert
      .dom(".strip")
      .doesNotHaveAttribute("data-d-scroll-at-end", "the end is out of view");

    const strip = find(".strip");
    strip.scrollLeft = 100;
    await nextFrame();

    assert
      .dom(".strip")
      .doesNotHaveAttribute(
        "data-d-scroll-at-start",
        "scrolling away drops the start mark"
      );
    assert
      .dom(".strip")
      .doesNotHaveAttribute(
        "data-d-scroll-at-end",
        "the middle rests on neither edge"
      );

    strip.scrollLeft = 200;
    await nextFrame();

    assert
      .dom(".strip")
      .hasAttribute("data-d-scroll-at-end", "", "reaching the end marks it");
  });

  test("leaves a strip that fits unmarked and reacts when it stops fitting", async function (assert) {
    await render(
      <template>
        <div
          class="strip"
          style="width: 400px; overflow-x: auto; white-space: nowrap"
          {{dScrollEdges}}
        >
          <span class="content" style="display: inline-block; width: 300px">
            fits
          </span>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".strip")
      .doesNotHaveAttribute(
        "data-d-scroll-overflow",
        "content that fits is not overflowing"
      );
    assert
      .dom(".strip")
      .hasAttribute(
        "data-d-scroll-axis",
        "horizontal",
        "a fitting strip still reports its horizontal axis"
      );

    find(".content").style.width = "900px";
    await nextFrame();

    assert
      .dom(".strip")
      .hasAttribute(
        "data-d-scroll-overflow",
        "",
        "content growing past the strip marks it as overflowing"
      );
  });

  test("reports along the vertical axis when asked", async function (assert) {
    await render(
      <template>
        <div
          class="strip"
          style="height: 100px; overflow-y: auto"
          {{dScrollEdges axis="vertical"}}
        >
          <div style="height: 300px">tall</div>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".strip")
      .hasAttribute("data-d-scroll-overflow", "", "the column overflows");
    assert
      .dom(".strip")
      .hasAttribute(
        "data-d-scroll-axis",
        "vertical",
        "the column reports its vertical axis"
      );
    assert.dom(".strip").hasAttribute("data-d-scroll-at-start", "");

    find(".strip").scrollTop = 200;
    await nextFrame();

    assert.dom(".strip").hasAttribute("data-d-scroll-at-end", "");
    assert.dom(".strip").doesNotHaveAttribute("data-d-scroll-at-start");
  });

  test("overflow strip: follows an axis change", async function (assert) {
    class AxisState {
      @tracked axis = "horizontal";
    }

    const state = new AxisState();

    await render(
      <template>
        <div
          class="axis-changing-strip"
          style="width: 100px; height: 100px; overflow: auto"
          {{dScrollEdges axis=state.axis}}
        >
          <div style="width: 300px; height: 300px"></div>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".axis-changing-strip")
      .hasAttribute(
        "data-d-scroll-axis",
        "horizontal",
        "the initial axis is horizontal"
      );

    state.axis = "vertical";
    await settled();
    await nextFrame();

    assert
      .dom(".axis-changing-strip")
      .hasAttribute(
        "data-d-scroll-axis",
        "vertical",
        "the stamped axis follows the argument"
      );
    assert
      .dom(".axis-changing-strip")
      .hasAttribute(
        "data-d-scroll-at-start",
        "",
        "the vertical axis starts at its leading edge"
      );

    const strip = find(".axis-changing-strip");
    strip.scrollTop = strip.scrollHeight - strip.clientHeight;
    await nextFrame();

    assert
      .dom(".axis-changing-strip")
      .hasAttribute(
        "data-d-scroll-at-end",
        "",
        "the vertical axis reports its measured trailing edge"
      );
    assert
      .dom(".axis-changing-strip")
      .doesNotHaveAttribute(
        "data-d-scroll-at-start",
        "the vertical axis no longer reports its leading edge"
      );
  });
});
