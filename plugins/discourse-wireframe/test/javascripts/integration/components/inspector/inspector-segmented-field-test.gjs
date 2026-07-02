import { click, render, settled } from "@ember/test-helpers";
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

  // Six icon options: enough that the control fits at a wide rail but folds
  // once the rail is dragged to its narrowest, which is what these tests flex.
  const SIX_ITEMS = ["a", "b", "c", "d", "e", "f"].map((value) => ({
    value,
    label: value.toUpperCase(),
    icon: "wf-align-left",
  }));

  test("folds to a dropdown when the inspector rail is narrow", async function (assert) {
    this.owner.lookup("service:wireframe-rail").setRightRailWidth(240);
    const items = SIX_ITEMS;
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="a" />
      </template>
    );

    assert
      .dom(".wireframe-segmented-field__dropdown")
      .exists("a narrow rail folds the six-option control to a dropdown");
    assert.dom(".d-segmented-control").doesNotExist();
  });

  test("keeps segments when the inspector rail is wide", async function (assert) {
    this.owner.lookup("service:wireframe-rail").setRightRailWidth(500);
    const items = SIX_ITEMS;
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="a" />
      </template>
    );

    assert.dom(".d-segmented-control").exists("a wide rail keeps segments");
    assert.dom(".wireframe-segmented-field__dropdown").doesNotExist();
  });

  test("re-widening the rail unfolds the control back to segments", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setRightRailWidth(240);
    const items = SIX_ITEMS;
    await render(
      <template>
        <InspectorSegmentedField @items={{items}} @value="a" />
      </template>
    );
    assert
      .dom(".wireframe-segmented-field__dropdown")
      .exists("folded while narrow");

    rail.setRightRailWidth(500);
    await settled();
    assert
      .dom(".d-segmented-control")
      .exists("widening the rail restores the segmented control");
  });
});
