import { click, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorSegmentedField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-segmented-field";

module("Integration | Wireframe | InspectorSegmentedField", function (hooks) {
  setupRenderingTest(hooks);

  test("renders icon segments when every option has an icon", async function (assert) {
    const items = [
      { value: "a", label: "A", icon: "wf-align-left" },
      { value: "b", label: "B", icon: "wf-align-center" },
    ];
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="a" />
      </template>
    );

    assert.dom(".d-segmented-control").exists("renders a segmented control");
    assert
      .dom(".d-segmented-control__text .d-icon")
      .exists({ count: 2 }, "each segment shows its icon");
    assert.dom("input[value='a']").isChecked();
  });

  test("shows labels for options without an icon (mixed set)", async function (assert) {
    const items = [
      { value: "auto", label: "Auto" },
      { value: "start", label: "Start", icon: "wf-align-start-vertical" },
    ];
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="auto" />
      </template>
    );

    assert.dom(".d-segmented-control").exists("still a segmented control");
    assert
      .dom(".d-segmented-control")
      .includesText("Auto", "the icon-less option keeps its text label");
    assert
      .dom(".d-segmented-control__text .d-icon")
      .exists({ count: 1 }, "only the iconned option renders an icon");
  });

  test("falls back to a dropdown when there are too many options", async function (assert) {
    const items = ["one", "two", "three", "four", "five", "six", "seven"].map(
      (value) => ({ value, label: value })
    );
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="one" />
      </template>
    );

    assert
      .dom(".wireframe-segmented-field__dropdown")
      .exists("renders the ComboBox fallback");
    assert
      .dom(".d-segmented-control")
      .doesNotExist("no segmented row when it would be too wide");
  });

  test("selecting a segment calls @onChange", async function (assert) {
    const captured = [];
    const onChange = (value) => captured.push(value);
    const items = [
      { value: "a", label: "A", icon: "wf-align-left" },
      { value: "b", label: "B", icon: "wf-align-center" },
    ];
    await render(
      <template>
        <InspectorSegmentedField
          @items={{items}}
          @value="a"
          @onChange={{onChange}}
        />
      </template>
    );

    await click("input[value='b']");
    assert.deepEqual(captured, ["b"]);
  });

  // Six icon options wrapped at extreme widths: no styling can fit six
  // segments in 40px, and any styling fits them in 5000px, so the fold
  // decisions below are deterministic even without the plugin stylesheet.
  const SIX_ITEMS = ["a", "b", "c", "d", "e", "f"].map((value) => ({
    value,
    label: value.toUpperCase(),
    icon: "wf-align-left",
  }));

  test("folds to a dropdown when the field is narrow", async function (assert) {
    const items = SIX_ITEMS;
    await render(
      <template>
        <div style="width: 40px">
          <InspectorSegmentedField @items={{items}} @value="a" />
        </div>
      </template>
    );

    assert
      .dom(".d-fit-swap")
      .hasAttribute("data-fit", "collapsed", "a narrow field folds");
    assert
      .dom(".wireframe-segmented-field__dropdown")
      .exists("the dropdown is the active rendition");
    assert
      .dom(".d-fit-swap__pane.--full")
      .hasStyle(
        { visibility: "hidden" },
        "the segmented row stays mounted but hidden for measurement"
      );
  });

  test("keeps segments when the field is wide", async function (assert) {
    const items = SIX_ITEMS;
    await render(
      <template>
        <div style="width: 5000px">
          <InspectorSegmentedField @items={{items}} @value="a" />
        </div>
      </template>
    );

    assert.dom(".d-fit-swap").hasAttribute("data-fit", "full");
    assert.dom(".d-segmented-control").exists("a wide field keeps segments");
    assert.dom(".wireframe-segmented-field__dropdown").doesNotExist();
  });

  test("re-widening the field unfolds the control back to segments", async function (assert) {
    const items = SIX_ITEMS;
    await render(
      <template>
        <div class="test-fit-wrap" style="width: 40px">
          <InspectorSegmentedField @items={{items}} @value="a" />
        </div>
      </template>
    );
    assert
      .dom(".wireframe-segmented-field__dropdown")
      .exists("folded while narrow");

    // A post-render width change reaches the fit pass through the
    // ResizeObserver, which fires outside the runloop (settled() does not
    // await it) — poll for the swapped state instead.
    document.querySelector(".test-fit-wrap").style.width = "5000px";
    await waitUntil(
      () => document.querySelector(".d-fit-swap")?.dataset.fit === "full"
    );

    assert
      .dom(".d-segmented-control")
      .exists("widening the field restores the segmented control");
    assert.dom(".wireframe-segmented-field__dropdown").doesNotExist();
  });
});
