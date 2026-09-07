import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { fillIn, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { imageComposition } from "discourse/blocks/image-value";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import DPositionPicker from "discourse/ui-kit/d-position-picker";
import ImageCompositionControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-composition-controls";
import InspectorDimensionField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-dimension-field";
import InspectorStepperField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-stepper-field";

module(
  "Integration | discourse-wireframe | shared image zoom",
  function (hooks) {
    setupRenderingTest(hooks);

    test("preserves incomplete numeric input and restores a cleared input on blur", async function (assert) {
      class Composition extends Service {
        @tracked draft = imageComposition({ zoom: 150 });

        matches() {
          return true;
        }

        preview(_target, patch) {
          this.draft = imageComposition({ ...this.draft, ...patch });
        }

        change(target, patch) {
          this.preview(target, patch);
        }

        cancel() {}
      }
      this.owner.register("service:wireframe-image-composition", Composition);
      const target = { blockKey: "image:zoom", argName: "image" };
      const value = { url: "/image.png", zoom: 150 };
      await render(
        <template>
          <ImageCompositionControls @target={{target}} @value={{value}} />
        </template>
      );
      const input = ".wireframe-image-composition__zoom input[type='number']";
      await fillIn(input, "2");
      assert
        .dom(input)
        .hasValue(
          "2",
          "a partial replacement is not overwritten by the clamped preview"
        );
      await fillIn(input, "250");
      await triggerEvent(input, "blur");
      assert.dom(input).hasValue("250");
      await fillIn(input, "");
      await triggerEvent(input, "blur");
      assert
        .dom(input)
        .hasValue("250", "an empty edit returns to the last valid zoom");
    });
  }
);

module(
  "Integration | discourse-wireframe | shared image position picker",
  function (hooks) {
    setupRenderingTest(hooks);

    test("drags from a preset and commits only once on release", async function (assert) {
      const previews = [];
      const commits = [];
      const preview = (value) => previews.push(value);
      const commit = (value) => commits.push(value);
      const cancel = () => {};
      const value = { x: 50, y: 50 };
      await render(
        <template>
          <DPositionPicker
            @value={{value}}
            @onPreview={{preview}}
            @onChange={{commit}}
            @onCancel={{cancel}}
          />
        </template>
      );
      const pad = find(".d-position-picker__pad");
      const bounds = pad.getBoundingClientRect();
      stubPointerCapture(".d-position-picker__pad");
      await triggerEvent(
        ".d-position-picker__preset:nth-child(5)",
        "pointerdown",
        {
          button: 0,
          pointerId: 1,
          clientX: bounds.left + bounds.width / 2,
          clientY: bounds.top + bounds.height / 2,
        }
      );
      await triggerEvent(pad, "pointermove", {
        pointerId: 1,
        clientX: bounds.left + bounds.width / 4,
        clientY: bounds.top + bounds.height * 0.75,
      });
      assert.deepEqual(
        previews.at(-1),
        { x: 25, y: 75 },
        "dragging the current point previews the new coordinates"
      );
      assert.strictEqual(commits.length, 0, "movement does not commit");
      await triggerEvent(pad, "pointerup", {
        pointerId: 1,
        clientX: bounds.left + bounds.width / 4,
        clientY: bounds.top + bounds.height * 0.75,
      });
      await triggerEvent(".d-position-picker__preset:nth-child(5)", "click", {
        detail: 1,
      });
      assert.deepEqual(
        commits,
        [{ x: 25, y: 75 }],
        "release click neither duplicates nor resets the adjustment"
      );
    });

    test("numeric edits preview until blur and keyboard presets remain accessible", async function (assert) {
      const commits = [];
      const preview = () => {};
      const commit = (value) => commits.push(value);
      const cancel = () => {};
      const value = { x: 50, y: 50 };
      await render(
        <template>
          <DPositionPicker
            @value={{value}}
            @onPreview={{preview}}
            @onChange={{commit}}
            @onCancel={{cancel}}
          />
        </template>
      );
      await fillIn("input[type='number']", "30");
      assert.strictEqual(commits.length, 0, "typing remains a draft");
      await triggerEvent("input[type='number']", "blur");
      assert.deepEqual(commits, [{ x: 30, y: 50 }], "blur commits once");
      await triggerEvent(".d-position-picker__preset:nth-child(9)", "click", {
        detail: 0,
      });
      assert.deepEqual(
        commits.at(-1),
        { x: 100, y: 100 },
        "keyboard activation selects the bottom right preset"
      );
    });
  }
);

module(
  "Integration | discourse-wireframe | inspector dimension field",
  function (hooks) {
    setupRenderingTest(hooks);

    test("unitless mode emits a Number, shows a suffix, and keeps a slider", async function (assert) {
      const captured = [];
      const onChange = (value) => captured.push(value);

      await render(
        <template>
          <InspectorDimensionField
            @value={{1}}
            @onChange={{onChange}}
            @unitless={{true}}
            @unit="rem"
            @slider={{true}}
            @min={{0}}
            @max={{4}}
            @step={{0.25}}
          />
        </template>
      );

      assert
        .dom(".wireframe-dimension-field__suffix")
        .hasText("rem", "shows the unit as a static suffix");
      assert
        .dom(".wireframe-dimension-field__slider")
        .exists("renders the slider");
      assert
        .dom("select.wireframe-dimension-field__unit")
        .doesNotExist("no unit selector in unitless mode");
      assert.dom(".wireframe-dimension-field__number").hasValue("1");

      await fillIn(".wireframe-dimension-field__number", "2");
      await triggerEvent(".wireframe-dimension-field__number", "change");

      assert.strictEqual(captured.at(-1), 2, "commits the typed value");
      assert.strictEqual(
        typeof captured.at(-1),
        "number",
        "the committed value stays a Number, never a string"
      );
    });

    test("clamps an out-of-range entry to the max", async function (assert) {
      const captured = [];
      const onChange = (value) => captured.push(value);

      await render(
        <template>
          <InspectorDimensionField
            @value={{1}}
            @onChange={{onChange}}
            @unitless={{true}}
            @min={{0}}
            @max={{4}}
          />
        </template>
      );

      await fillIn(".wireframe-dimension-field__number", "10");
      await triggerEvent(".wireframe-dimension-field__number", "change");

      assert.strictEqual(captured.at(-1), 4, "clamps 10 down to the max of 4");
    });

    test("unit mode emits a CSS string and reserializes on unit change", async function (assert) {
      const captured = [];
      const onChange = (value) => captured.push(value);
      const units = ["px", "rem"];

      await render(
        <template>
          <InspectorDimensionField
            @value="16px"
            @onChange={{onChange}}
            @units={{units}}
          />
        </template>
      );

      assert.dom(".wireframe-dimension-field__number").hasValue("16");
      assert.dom("select.wireframe-dimension-field__unit").hasValue("px");

      await fillIn("select.wireframe-dimension-field__unit", "rem");
      assert.strictEqual(
        captured.at(-1),
        "16rem",
        "switching the unit reserializes the value"
      );

      await fillIn(".wireframe-dimension-field__number", "20");
      await triggerEvent(".wireframe-dimension-field__number", "change");
      assert.strictEqual(
        captured.at(-1),
        "20rem",
        "the numeric edit keeps the selected unit"
      );
    });
  }
);

module(
  "Integration | discourse-wireframe | inspector stepper field",
  function (hooks) {
    setupRenderingTest(hooks);

    test("increment / decrement nudge by the step and clamp at bounds", async function (assert) {
      const captured = [];
      const onChange = (value) => captured.push(value);

      await render(
        <template>
          <InspectorStepperField
            @value={{3}}
            @onChange={{onChange}}
            @min={{1}}
            @max={{12}}
          />
        </template>
      );

      await triggerEvent(".wireframe-stepper-field__btn:last-child", "click");
      assert.strictEqual(captured.at(-1), 4, "increment adds the step");

      await triggerEvent(".wireframe-stepper-field__btn:first-child", "click");
      assert.strictEqual(captured.at(-1), 2, "decrement subtracts the step");
    });

    test("typing an over-max value clamps to the max", async function (assert) {
      const captured = [];
      const onChange = (value) => captured.push(value);

      await render(
        <template>
          <InspectorStepperField
            @value={{3}}
            @onChange={{onChange}}
            @min={{1}}
            @max={{12}}
          />
        </template>
      );

      await fillIn(".wireframe-stepper-field__number", "100");
      await triggerEvent(".wireframe-stepper-field__number", "change");

      assert.strictEqual(captured.at(-1), 12, "clamps 100 down to the max");
    });
  }
);
