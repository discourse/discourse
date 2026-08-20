import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorDimensionField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-dimension-field";
import InspectorStepperField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-stepper-field";

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
