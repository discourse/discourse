import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Controls | Menu", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    let data = { foo: "item-2" };
    const mutateData = (x) => (data = x);

    await render(<template>
      <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
        <form.Field @name="foo" @title="Foo" as |field|>
          <field.Menu as |menu|>
            <menu.Item @value="item-1">Item 1</menu.Item>
            <menu.Item @value="item-2">Item 2</menu.Item>
            <menu.Item @value="item-3">Item 3</menu.Item>
          </field.Menu>
        </form.Field>
      </Form>
    </template>);

    assert.deepEqual(data, { foo: "item-2" });
    assert.form().field("foo").hasValue("item-2");

    await formKit().field("foo").select("item-3");
    await formKit().submit();

    assert.deepEqual(data, { foo: "item-3" });
    assert.form().field("foo").hasValue("item-3");
  });

  test("when disabled", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
          <field.Menu />
        </form.Field>
      </Form>
    </template>);

    assert.dom(".form-kit__control-menu").hasAttribute("disabled");
  });
});
