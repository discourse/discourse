import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { buildSimulatedViewport } from "discourse/blocks/conditions/viewport";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ViewDrawer from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/view-drawer";

module(
  "Integration | discourse-wireframe | Component | view-drawer",
  function (hooks) {
    setupRenderingTest(hooks);

    const noop = () => {};

    // A couple of frames so the segmented control's rAF-driven slider settles.
    const nextFrame = () =>
      new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));

    hooks.afterEach(function () {
      document.body.classList.remove(
        "wireframe-active",
        "wireframe-active--dim-non-editable"
      );
    });

    test("renders the dim toggle and simulation controls when open", async function (assert) {
      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );

      assert
        .dom(".wireframe-view-drawer")
        .exists("the drawer renders when open");
      assert
        .dom(".wireframe-view-drawer__dim .d-toggle-switch__checkbox")
        .exists("the dim toggle renders")
        .hasAria("checked", "true", "reflecting the passed-in dim state");
      assert
        .dom(".wireframe-simulation__persona.select-kit")
        .exists("the persona combobox renders");
      assert
        .dom(".wireframe-simulation__viewport.d-segmented-control")
        .exists("the viewport segmented control renders");
    });

    test("the persona dropdown shows an icon and a description for each option", async function (assert) {
      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );

      await selectKit(".wireframe-simulation__persona").expand();
      assert
        .dom(".dropdown-select-box-row .desc")
        .exists("each persona row carries a description");
      assert
        .dom(".dropdown-select-box-row .icons")
        .exists("each persona row carries an icon");
    });

    test("the viewport segment reflects the active simulated size", async function (assert) {
      const simulation = this.owner.lookup("service:wireframe-simulation");
      // `xl` marks sm..xl true; the control must map that back to "desktop"
      // (the largest chosen size), not the smallest true breakpoint.
      simulation.setViewport(buildSimulatedViewport({ breakpoint: "xl" }));

      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );

      assert
        .dom(".wireframe-simulation__viewport input[value='desktop']")
        .isChecked("an xl viewport selects the desktop segment");
    });

    test("clicking a viewport segment slides the highlight to it", async function (assert) {
      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );

      await nextFrame();

      const fieldset = find(".wireframe-simulation__viewport");
      const before = fieldset.style.getPropertyValue("--slider-x");

      await click(".wireframe-simulation__viewport input[value='desktop']");
      await nextFrame();

      assert
        .dom(".wireframe-simulation__viewport input[value='desktop']")
        .isChecked("the clicked segment becomes selected");
      assert.notStrictEqual(
        fieldset.style.getPropertyValue("--slider-x"),
        before,
        "the slider repositions to the clicked segment"
      );
      assert
        .dom(".wireframe-simulation__viewport .d-segmented-control__slider")
        .hasClass("is-animated", "the slide transition is enabled");
    });

    test("is exempt from the dim system so its transitions survive", async function (assert) {
      // Reproduces the real editor: the dim system's blanket
      // `body.wireframe-active *:not(...) { transition: opacity }` would clobber
      // the segmented slider's transform transition (and fade the drawer) unless
      // the drawer carries the shared `.wireframe-editor-overlay` exemption.
      document.body.classList.add(
        "wireframe-active",
        "wireframe-active--dim-non-editable"
      );

      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );
      await nextFrame();

      assert
        .dom(".wireframe-view-drawer")
        .hasClass(
          "wireframe-editor-overlay",
          "the drawer carries the shared exemption marker"
        );
      assert.strictEqual(
        getComputedStyle(find(".wireframe-view-drawer")).opacity,
        "1",
        "the drawer is not dimmed"
      );
      // The blanket dim transition would force `transition-property: opacity`
      // onto the slider (clobbering its transform slide); exemption means it
      // never carries opacity as its transition property.
      assert.notStrictEqual(
        getComputedStyle(
          find(".wireframe-simulation__viewport .d-segmented-control__slider")
        ).transitionProperty,
        "opacity",
        "the slider's transition isn't clobbered to opacity by the dim system"
      );
    });

    test("renders nothing when closed", async function (assert) {
      await render(
        <template>
          <ViewDrawer
            @isOpen={{false}}
            @dimNonEditable={{true}}
            @onToggleDim={{noop}}
            @onClose={{noop}}
          />
        </template>
      );

      assert
        .dom(".wireframe-view-drawer")
        .doesNotExist("a closed drawer is not rendered");
    });

    test("the dim toggle and close button invoke their handlers", async function (assert) {
      let toggled = 0;
      let closed = 0;
      const onToggle = () => (toggled += 1);
      const onClose = () => (closed += 1);
      await render(
        <template>
          <ViewDrawer
            @isOpen={{true}}
            @dimNonEditable={{false}}
            @onToggleDim={{onToggle}}
            @onClose={{onClose}}
          />
        </template>
      );

      await click(".wireframe-view-drawer__dim .d-toggle-switch__checkbox");
      assert.strictEqual(
        toggled,
        1,
        "clicking the dim toggle calls onToggleDim"
      );

      await click(".wireframe-view-drawer__close");
      assert.strictEqual(closed, 1, "clicking close calls onClose");
    });
  }
);
