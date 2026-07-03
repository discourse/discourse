import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFitSwap from "discourse/ui-kit/d-fit-swap";

// Content widths are forced with inline styles, so the fit decisions in these
// tests are deterministic without any stylesheet.
module("Integration | ui-kit | DFitSwap", function (hooks) {
  setupRenderingTest(hooks);

  test("collapses when the full rendition does not fit", async function (assert) {
    await render(
      <template>
        <div style="width: 120px">
          <DFitSwap>
            <:full><div
                class="full-marker"
                style="width: 400px"
              >wide</div></:full>
            <:collapsed><div class="collapsed-marker">compact</div></:collapsed>
          </DFitSwap>
        </div>
      </template>
    );

    assert.dom(".d-fit-swap").hasAttribute("data-fit", "collapsed");
    assert.dom(".collapsed-marker").exists("the collapsed rendition is active");
    assert
      .dom(".full-marker")
      .exists("the full rendition stays mounted for measurement");
    assert
      .dom(".d-fit-swap__pane.--full")
      .hasStyle(
        { visibility: "hidden", position: "absolute" },
        "the full pane is hidden and out of flow"
      );
  });

  test("stays full when there is room", async function (assert) {
    await render(
      <template>
        <div style="width: 1000px">
          <DFitSwap>
            <:full><div class="full-marker" style="width: 200px">n</div></:full>
            <:collapsed><div class="collapsed-marker">c</div></:collapsed>
          </DFitSwap>
        </div>
      </template>
    );

    assert.dom(".d-fit-swap").hasAttribute("data-fit", "full");
    assert
      .dom(".collapsed-marker")
      .doesNotExist("the collapsed rendition does not render while full");
    assert
      .dom(".d-fit-swap__pane.--full")
      .hasStyle({ visibility: "visible" }, "the full pane is shown");
  });

  test("a tracked @remeasureOn change re-measures without a resize", async function (assert) {
    const state = new (class {
      @tracked contentWidth = 100;

      get widthStyle() {
        return trustHTML(`width: ${this.contentWidth}px`);
      }
    })();

    await render(
      <template>
        <div style="width: 300px">
          <DFitSwap @remeasureOn={{state.contentWidth}}>
            <:full><div style={{state.widthStyle}}>content</div></:full>
            <:collapsed><div class="collapsed-marker">c</div></:collapsed>
          </DFitSwap>
        </div>
      </template>
    );

    assert.dom(".d-fit-swap").hasAttribute("data-fit", "full");

    // Widen the content without touching the host: the host's box never
    // resizes, so only the remeasureOn entanglement can trigger the re-fit.
    state.contentWidth = 800;
    await settled();

    assert
      .dom(".d-fit-swap")
      .hasAttribute("data-fit", "collapsed", "content growth folds the swap");

    state.contentWidth = 100;
    await settled();

    assert
      .dom(".d-fit-swap")
      .hasAttribute("data-fit", "full", "content shrink restores it");
  });

  test("folds inside a start-aligned flex column at a fixed width", async function (assert) {
    // Mirrors a form field container: a flex column aligning items to the
    // start makes children shrink-to-fit, which would let the host grow to the
    // full rendition's width and never fold; the host's align-self: stretch
    // must restore the container-determined width.
    await render(
      <template>
        <div
          style="display: flex; flex-direction: column; align-items: flex-start; width: 120px"
        >
          <DFitSwap>
            <:full><div style="width: 400px">wide</div></:full>
            <:collapsed><div class="collapsed-marker">c</div></:collapsed>
          </DFitSwap>
        </div>
      </template>
    );

    assert.dom(".d-fit-swap").hasAttribute("data-fit", "collapsed");
    assert.dom(".collapsed-marker").exists();
  });
});
