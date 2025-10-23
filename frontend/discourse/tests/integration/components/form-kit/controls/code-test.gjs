import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Controls | Code", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    let data = { foo: null };
    const mutateData = (x) => (data = x);

    await render(
      <template>
        <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
          <form.Field @name="foo" @title="Foo" as |field|>
            <field.Code @height={{100}} style="width: 200px" />
          </form.Field>
        </Form>
      </template>
    );

    assert.deepEqual(data, { foo: null });
    assert.form().field("foo").hasValue("");

    await formKit().field("foo").fillIn("bar");
    await formKit().submit();

    assert.deepEqual(data, { foo: "bar" });
    assert.form().field("foo").hasValue("bar");
  });

  test("when disabled", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
            <field.Code />
          </form.Field>
        </Form>
      </template>
    );

    assert.dom(".ace_text-input").hasAttribute("readonly");
  });
});
