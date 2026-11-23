import { click, find, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Controls | Menu", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    let data = { foo: "item-2" };
    const mutateData = (x) => (data = x);

    await render(
      <template>
        <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
          <form.Field @name="foo" @title="Foo" @type="menu" as |field|>
            <field.Control as |menu|>
              <menu.Item @value="item-1">Item 1</menu.Item>
              <menu.Item @value="item-2">Item 2</menu.Item>
              <menu.Item @value="item-3">Item 3</menu.Item>
            </field.Control>
          </form.Field>
        </Form>
      </template>
    );

    assert.deepEqual(data, { foo: "item-2" });
    assert.form().field("foo").hasValue("item-2");

    await formKit().field("foo").select("item-3");
    await formKit().submit();

    assert.deepEqual(data, { foo: "item-3" });
    assert.form().field("foo").hasValue("item-3");
  });

  test("@preservePlacement keeps the opening placement when results shrink", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @name="foo" @title="Foo" @type="menu" as |field|>
            <field.Control @preservePlacement={{true}} as |menu|>
              <menu.Container>
                <div
                  data-test-results
                  style="height: 200px; width: 100px;"
                >Results</div>
              </menu.Container>
            </field.Control>
          </form.Field>
        </Form>
      </template>
    );
    const trigger = find(".form-kit__control-menu-trigger");
    // Leave room only above and below the trigger.
    trigger.style.width = `${window.innerWidth - 40}px`;
    trigger.style.maxWidth = "none";
    const triggerRect = new DOMRect(
      20,
      window.innerHeight - 100,
      trigger.offsetWidth,
      trigger.offsetHeight
    );
    sinon.stub(trigger, "getBoundingClientRect").returns(triggerRect);
    await click(trigger);

    const menu = find(".fk-d-menu");
    const openingPlacement = menu.dataset.placement;
    assert.strictEqual(
      openingPlacement.split("-")[0],
      "top",
      "opens above the trigger when it cannot fit below"
    );

    const openingBottom = menu.getBoundingClientRect().bottom;
    find("[data-test-results]").style.height = "20px";
    await waitUntil(
      () => Math.abs(menu.getBoundingClientRect().bottom - openingBottom) < 2
    );
    assert.strictEqual(
      menu.dataset.placement,
      openingPlacement,
      "FormKit forwards the option and the menu stays above after resizing"
    );
  });

  test("when disabled", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field
            @disabled={{true}}
            @name="foo"
            @title="Foo"
            @type="menu"
            as |field|
          >
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-menu-trigger").hasAttribute("disabled");
  });

  test("@selection", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @name="foo" @title="Foo" @type="menu" as |field|>
            <field.Control @selection="Current item" as |menu|>
              <menu.Item @value="item-1">Item 1</menu.Item>
            </field.Control>
          </form.Field>
        </Form>
      </template>
    );

    assert
      .dom(".form-kit__control-menu-trigger .d-button-label")
      .hasText("Current item");
  });
});
