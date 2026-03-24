import { blur, click, fillIn, focus, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Color",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { color: "FF0000" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.strictEqual(formKit().field("color").value(), "FF0000");

      await fillIn(".form-kit__control-color-input-hex", "00FF00");
      await formKit().submit();

      assert.strictEqual(data.color, "00FF00");
    });

    test("shows # prefix by default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.true(formKit().field("color").hasPrefix());
    });

    test("hides # prefix when @allowNamedColors is true", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @allowNamedColors={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.false(formKit().field("color").hasPrefix());
    });

    test("with predefined colors", async function (assert) {
      const colors = ["FF0000", "00FF00", "0000FF"];
      let data = { color: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @colors={{colors}} />
            </form.Field>
          </Form>
        </template>
      );

      const swatches = formKit().field("color").swatches();
      assert.strictEqual(swatches.length, 3);

      await formKit().field("color").select("00FF00");
      await formKit().submit();

      assert.strictEqual(data.color, "00FF00");
    });

    test("marks used colors", async function (assert) {
      const colors = ["FF0000", "00FF00", "0000FF"];
      const usedColors = ["00FF00"];

      await render(
        <template>
          <Form as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @colors={{colors}} @usedColors={{usedColors}} />
            </form.Field>
          </Form>
        </template>
      );

      const swatches = formKit().field("color").swatches();
      assert.false(swatches[0].isUsed);
      assert.false(swatches[1].isUsed);
      assert.true(swatches[2].isUsed);
    });

    test("sorting used colors does not mutate the original array", async function (assert) {
      const colors = ["FF0000", "00FF00", "0000FF"];
      const usedColors = ["00FF00"];

      await render(
        <template>
          <Form as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @colors={{colors}} @usedColors={{usedColors}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.deepEqual(
        colors,
        ["FF0000", "00FF00", "0000FF"],
        "original colors array should not be mutated"
      );
    });

    test("when disabled", async function (assert) {
      const colors = ["FF0000", "00FF00"];

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="color"
              @name="color"
              @title="Color"
              @disabled={{true}}
              as |field|
            >
              <field.Control @colors={{colors}} />
            </form.Field>
          </Form>
        </template>
      );

      const field = formKit().field("color");
      assert.true(field.isDisabled());
      assert.true(field.pickerElement.disabled);
      assert.true(field.swatches().every((s) => s.isDisabled));
    });

    test("native color picker updates field", async function (assert) {
      let data = { color: "FF0000" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      const picker = formKit().field("color").pickerElement;
      picker.value = "#00FF00";
      picker.dispatchEvent(new Event("input", { bubbles: true }));

      await formKit().submit();

      assert.strictEqual(data.color, "00ff00");
    });

    test("picker displays named colors correctly", async function (assert) {
      let data = { color: "purple" };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @allowNamedColors={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      const picker = formKit().field("color").pickerElement;
      assert.strictEqual(picker.value, "#800080");
    });

    test("@fallbackValue restores value when field is cleared", async function (assert) {
      let data = { color: "" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control @fallbackValue="AABBCC" />
            </form.Field>
          </Form>
        </template>
      );

      await focus(".form-kit__control-color-input-hex");
      await fillIn(".form-kit__control-color-input-hex", "");
      await blur(".form-kit__control-color-input-hex");

      assert.strictEqual(formKit().field("color").value(), "AABBCC");
    });

    test("@collapseSwatches and @collapseSwatchesLabel", async function (assert) {
      const colors = ["FF0000", "00FF00", "0000FF"];
      let data = { color: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="color" @name="color" @title="Color" as |field|>
              <field.Control
                @colors={{colors}}
                @collapseSwatches={{true}}
                @collapseSwatchesLabel="Pick a preset"
              />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__control-color-swatches-btn")
        .hasAttribute("title", "Pick a preset");
      assert.dom(".form-kit__control-color-swatch").doesNotExist();

      await click(".form-kit__control-color-swatches-btn");
      await click('.form-kit__control-color-swatch[data-color="00FF00"]');
      await formKit().submit();

      assert.strictEqual(data.color, "00FF00");
    });
  }
);
