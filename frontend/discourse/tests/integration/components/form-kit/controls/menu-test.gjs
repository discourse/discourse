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
    const data = { foo: "item-1" };

    await render(
      <template>
        <Form @data={{data}} as |form|>
          <form.Field
            @helpText="Suggested value"
            @name="foo"
            @title="Foo"
            @type="menu"
            as |field|
          >
            <field.Control @selection="Current item" as |menu|>
              <menu.Item @value="item-1">Current item</menu.Item>
              <menu.Item @value="item-2">Another item</menu.Item>
            </field.Control>
          </form.Field>
        </Form>
      </template>
    );

    const trigger = find(".form-kit__control-menu-trigger");
    const labelIds = [
      find(".form-kit__container-title").id,
      find(".form-kit__control-menu-trigger .d-button-label").id,
    ];

    assert.dom(trigger).hasText("Current item", "shows the current selection");
    assert
      .dom(trigger)
      .hasAttribute(
        "aria-labelledby",
        labelIds.join(" "),
        "names the field and its selection"
      );
    assert
      .dom(trigger)
      .hasAttribute(
        "aria-describedby",
        find(".form-kit__container-help-text").id,
        "references the field hint"
      );

    await click(trigger);

    assert
      .dom('.form-kit__control-menu-item[data-value="item-1"] button')
      .hasAttribute("aria-current", "true", "marks the current option");
    assert
      .dom('.form-kit__control-menu-item[data-value="item-2"] button')
      .doesNotHaveAttribute("aria-current", "leaves other options unmarked");
  });

  test("a mobile menu with a hidden field title names its trigger and dialog", async function (assert) {
    sinon.stub(this.owner.lookup("service:site"), "mobileView").value(true);

    await render(
      <template>
        <Form as |form|>
          <form.Field
            @name="foo"
            @showTitle={{false}}
            @title="Foo"
            @type="menu"
            as |field|
          >
            <field.Control @selection="Current item" as |menu|>
              <menu.Item @value="item-1">Current item</menu.Item>
            </field.Control>
          </form.Field>
        </Form>
      </template>
    );

    const trigger = find(".form-kit__control-menu-trigger");
    assert
      .dom(trigger)
      .hasAttribute(
        "aria-labelledby",
        find(".form-kit__control-menu-trigger .d-button-label").id,
        "names the trigger from the visible selection"
      );

    await click(trigger);
    assert
      .dom(".fk-d-menu-modal")
      .hasAttribute(
        "aria-label",
        "Foo",
        "names the dialog from the field title"
      );
    assert
      .dom(".fk-d-menu-modal .form-kit__control-menu-item .btn")
      .isFocused("moves focus into the mobile menu when it opens");
  });
});
