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
          <form.Field @type="code" @name="foo" @title="Foo" as |field|>
            <field.Control @height={{100}} style="width: 200px" />
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

  test("@height", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @type="code" @name="foo" @title="Foo" as |field|>
            <field.Control @height={{100}} />
          </form.Field>
        </Form>
      </template>
    );

    assert.strictEqual(
      document.querySelector(".form-kit__control-code").style.height,
      "100px"
    );
  });

  test("@lang", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @type="code" @name="foo" @title="Foo" as |field|>
            <field.Control @lang="sql" />
          </form.Field>
        </Form>
      </template>
    );

    assert.strictEqual(
      document
        .querySelector(".form-kit__control-code")
        .aceEditor.getSession()
        .getMode().$id,
      "ace/mode/sql"
    );
  });

  test("when disabled", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field
            @type="code"
            @name="foo"
            @title="Foo"
            @disabled={{true}}
            as |field|
          >
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );

    assert.dom(".ace_text-input").hasAttribute("readonly");
  });
});
