import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { fillIn, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Layout from "discourse/blocks/builtin/layout";
import { imageComposition } from "discourse/blocks/image-value";
import Form from "discourse/components/form";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { i18n } from "discourse-i18n";
import ImageCompositionControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-composition-controls";
import ImagePositionPicker from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-position-picker";
import InspectorDimensionField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-dimension-field";
import InspectorStepperField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-stepper-field";
import InspectorContainerArgsForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-container-args-form";

module(
  "Integration | discourse-wireframe | automatic placement grow",
  function (hooks) {
    setupRenderingTest(hooks);

    for (const mode of ["row", "stack"]) {
      test(`${mode} distinguishes automatic sizing from explicit zero and restores it when cleared`, async function (assert) {
        const calls = [];
        class Selection extends Service {
          selectedBlockData = {
            isRegistered: true,
            parentChildArgsSchema: getBlockMetadata(Layout).childArgs,
            parentArgsSnapshot: { mode },
            containerArgsSnapshot: {},
          };
        }
        class EntryConfig extends Service {
          updateSelectedContainerArg(namespace, name, value) {
            calls.push({ namespace, name, value });
          }
        }
        this.owner.unregister("service:wireframe-selection");
        this.owner.register("service:wireframe-selection", Selection);
        this.owner.unregister("service:wireframe-entry-config");
        this.owner.register("service:wireframe-entry-config", EntryConfig);
        await render(<template><InspectorContainerArgsForm /></template>);
        const input = ".wireframe-stepper-field__number";
        assert
          .dom(input)
          .hasValue("", "omitted grow does not claim an explicit zero");
        assert
          .dom(input)
          .hasAttribute(
            "placeholder",
            i18n("blocks.builtin.layout.placement.automatic"),
            "the empty value explains automatic allocation"
          );
        assert.strictEqual(
          calls.length,
          0,
          "opening placement does not write defaults"
        );

        await fillIn(input, "0");
        await triggerEvent(input, "change");
        assert.deepEqual(
          calls.at(-1),
          { namespace: mode, name: "flexGrow", value: 0 },
          "zero is an intentional no-grow override"
        );
        assert.dom(input).hasValue("0", "explicit zero stays visible");

        await fillIn(input, "");
        await triggerEvent(input, "change");
        assert.deepEqual(
          calls.at(-1),
          { namespace: mode, name: "flexGrow", value: undefined },
          "clearing restores an omitted value, not invalid null or zero"
        );
        assert.dom(input).hasValue("", "automatic sizing is shown again");
        await triggerEvent(".wireframe-stepper-field__btn:last-child", "click");
        assert.deepEqual(
          calls.at(-1),
          { namespace: mode, name: "flexGrow", value: 1 },
          "increment opts into a numeric grow factor"
        );
      });
    }
  }
);

module(
  "Integration | discourse-wireframe | shared image zoom",
  function (hooks) {
    setupRenderingTest(hooks);

    test("unit controls show percentage addons for image coordinates and zoom", async function (assert) {
      class Composition extends Service {
        matches() {
          return false;
        }
      }
      this.owner.register("service:wireframe-image-composition", Composition);
      const target = { blockKey: "image:units", argName: "image" };
      const value = { url: "/image.png", zoom: 150 };
      await render(
        <template>
          <div style="width: 300px;">
            <ImageCompositionControls @target={{target}} @value={{value}} />
          </div>
        </template>
      );
      assert
        .dom(".form-kit__after-input")
        .exists({ count: 3 }, "each percentage uses a FormKit suffix");
      assert.dom("input[aria-label='X (%)']").exists();
      assert.dom("input[aria-label='Y (%)']").exists();
      assert
        .dom(".wireframe-image-composition__zoom input[type='number']")
        .hasAttribute("aria-label", "Zoom (%)");
    });

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
          <ImagePositionPicker
            @onCancel={{cancel}}
            @onChange={{commit}}
            @onPreview={{preview}}
            @value={{value}}
          />
        </template>
      );
      const pad = find(".wireframe-image-position-picker__pad");
      const bounds = pad.getBoundingClientRect();
      stubPointerCapture(".wireframe-image-position-picker__pad");
      await triggerEvent(
        ".wireframe-image-position-picker__preset:nth-child(5)",
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
      await triggerEvent(
        ".wireframe-image-position-picker__preset:nth-child(5)",
        "click",
        {
          detail: 1,
        }
      );
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
          <ImagePositionPicker
            @onCancel={{cancel}}
            @onChange={{commit}}
            @onPreview={{preview}}
            @value={{value}}
          />
        </template>
      );
      await fillIn("input[type='number']", "30");
      assert.strictEqual(commits.length, 0, "typing remains a draft");
      await triggerEvent("input[type='number']", "blur");
      assert.deepEqual(commits, [{ x: 30, y: 50 }], "blur commits once");
      await triggerEvent(
        ".wireframe-image-position-picker__preset:nth-child(9)",
        "click",
        {
          detail: 0,
        }
      );
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
            @max={{4}}
            @min={{0}}
            @onChange={{onChange}}
            @slider={{true}}
            @step={{0.25}}
            @unit="rem"
            @unitless={{true}}
            @value={{1}}
          />
        </template>
      );

      assert
        .dom(".wireframe-dimension-field .form-kit__after-input")
        .hasText("rem", "shows the unit as a static suffix");
      assert
        .dom(".wireframe-dimension-field__slider")
        .exists("renders the slider");
      assert
        .dom("select.wireframe-dimension-field__unit")
        .doesNotExist("no unit selector in unitless mode");
      assert.dom(".wireframe-dimension-field__number").hasValue("1");

      const input = find(".wireframe-dimension-field__number");
      input.value = "2";
      await triggerEvent(input, "input");
      assert.deepEqual(captured, [], "typing does not commit the dimension");
      await triggerEvent(input, "change");

      assert.deepEqual(captured, [2], "commits the typed value once");
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
            @max={{4}}
            @min={{0}}
            @onChange={{onChange}}
            @unitless={{true}}
            @value={{1}}
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
            @onChange={{onChange}}
            @units={{units}}
            @value="16px"
          />
        </template>
      );

      assert.dom(".wireframe-dimension-field__number").hasValue("16");
      assert.dom("select.wireframe-dimension-field__unit").hasValue("px");
      assert
        .dom(".form-kit__after-input select")
        .exists("unit selector uses the shared addon container");

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

    test("unit controls retain the FormKit host and disabled field bindings", async function (assert) {
      const units = ["px", "rem"];
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @disabled={{true}}
              @name="size"
              @title="Size"
              @type="custom"
              as |field|
            >
              <field.Control>
                <InspectorDimensionField
                  @custom={{field}}
                  @max={{100}}
                  @min={{0}}
                  @slider={{true}}
                  @units={{units}}
                />
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );
      assert.dom("form").exists({ count: 1 }, "does not nest another form");
      assert
        .dom("input[type='number']")
        .isDisabled("numeric input respects disabled state");
      assert.dom("select").isDisabled("unit selector respects disabled state");
      assert
        .dom("input[type='range']")
        .isDisabled("slider respects disabled state");
      assert
        .dom("input[type='number']")
        .hasAttribute(
          "id",
          find("label").htmlFor,
          "field label targets the numeric control"
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
            @max={{12}}
            @min={{1}}
            @onChange={{onChange}}
            @value={{3}}
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
            @max={{12}}
            @min={{1}}
            @onChange={{onChange}}
            @value={{3}}
          />
        </template>
      );

      await fillIn(".wireframe-stepper-field__number", "100");
      await triggerEvent(".wireframe-stepper-field__number", "change");

      assert.strictEqual(captured.at(-1), 12, "clamps 100 down to the max");
    });
  }
);
