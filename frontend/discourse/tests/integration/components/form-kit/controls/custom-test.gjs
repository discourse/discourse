import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { ITEMS } from "discourse/tests/helpers/d-select-hosts";
import formKit from "discourse/tests/helpers/form-kit-helper";
import DSelect from "discourse/ui-kit/select/d-select";

module(
  "Integration | Component | FormKit | Controls | Custom",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @description="Bar"
              @name="foo"
              @title="Foo"
              @type="custom"
              as |field|
            >
              <field.Control>
                <input class="custom-test" />
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__container-title").hasText("Foo (optional)");
      assert.dom(".form-kit__container-description").hasText("Bar");
    });

    test("a menu opened from the control keeps its own width", async function (assert) {
      await render(
        <template>
          <div style="position: relative; width: 1200px">
            <Form as |form|>
              <form.Field
                @name="fruit"
                @title="Fruit"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <DSelect @items={{ITEMS}} />
                </field.Control>
              </form.Field>
            </Form>
          </div>
        </template>
      );
      await dSelect().open();

      const trigger = dSelect().element().getBoundingClientRect().width;
      const menu = document
        .querySelector(".d-select__content")
        .getBoundingClientRect().width;
      assert.true(
        Math.abs(menu - trigger) < 1,
        `the menu matches its trigger (${menu} vs ${trigger}), not the whole container`
      );
    });

    test("a tooltip opened from the control keeps its own width", async function (assert) {
      await render(
        <template>
          <div style="position: relative; width: 1200px">
            <Form as |form|>
              <form.Field @name="hint" @title="Hint" @type="custom" as |field|>
                <field.Control>
                  <DTooltip @content="Hi" @icon="circle-info" />
                </field.Control>
              </form.Field>
            </Form>
          </div>
        </template>
      );
      await triggerEvent(".fk-d-tooltip__trigger", "pointermove");

      const control = document
        .querySelector(".form-kit__control-custom")
        .getBoundingClientRect().width;
      const tooltip = document
        .querySelector(".fk-d-tooltip__content")
        .getBoundingClientRect().width;
      assert.true(
        tooltip < control,
        `the tooltip fits its text (${tooltip}), not the control (${control})`
      );
    });

    test("form helpers drive a DSelect field", async function (assert) {
      const data = { fruit: 1, fruits: [1] };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="fruit" @title="Fruit" @type="custom" as |field|>
              <field.Control>
                <DSelect
                  @items={{ITEMS}}
                  @onChange={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            </form.Field>
            <form.Field
              @name="fruits"
              @title="Fruits"
              @type="custom"
              as |field|
            >
              <field.Control>
                <DSelect
                  @items={{ITEMS}}
                  @multiple={{true}}
                  @onChange={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("fruit").hasValue("1");
      await formKit().field("fruit").select(3);
      assert.form().field("fruit").hasValue("3");

      assert.form().field("fruits").hasValue("1");
      await formKit().field("fruits").select(2);
      assert.form().field("fruits").hasValue("1,2");
    });

    test("FormKit value reads use single and multiple DSelect root hooks", async function (assert) {
      const data = { fruit: 1, fruits: [1] };
      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="fruit" @title="Fruit" @type="custom" as |field|>
              <field.Control>
                <DSelect
                  @items={{ITEMS}}
                  @onChange={{field.set}}
                  @value={{field.value}}
                  @variant="static"
                />
              </field.Control>
            </form.Field>
            <form.Field
              @name="fruits"
              @title="Fruits"
              @type="custom"
              as |field|
            >
              <field.Control>
                <DSelect
                  @items={{ITEMS}}
                  @multiple={{true}}
                  @onChange={{field.set}}
                  @value={{field.value}}
                  @variant="button"
                />
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );
      const form = formKit();
      assert.strictEqual(
        form.field("fruit").value(),
        "1",
        "single value is a string"
      );
      assert.strictEqual(
        form.field("fruits").value(),
        "1",
        "multiple value is a string"
      );
      await form.field("fruit").select(3);
      await form.field("fruits").select(2);
      assert.strictEqual(
        form.field("fruit").value(),
        "3",
        "single value reflects selection"
      );
      assert.strictEqual(
        form.field("fruits").value(),
        "1,2",
        "multiple values stay comma joined"
      );
      assert.form().field("fruits").hasValue("1,2");
      assert
        .dom(".d-select__panel")
        .doesNotExist("FormKit selection closes the panel");
    });
  }
);
