import { fn, hash } from "@ember/helper";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Form", function (hooks) {
  setupRenderingTest(hooks);

  test("@onSubmit", async function (assert) {
    const done = assert.async();

    const onSubmit = (data) => {
      assert.deepEqual(data.foo, 1);
      done();
    };

    await render(<template>
      <Form @data={{hash foo=1}} @onSubmit={{onSubmit}} />
    </template>);

    await formKit().submit();
  });

  test("@validate", async function (assert) {
    const done = assert.async();
    const validate = async (data, { addError }) => {
      assert.deepEqual(data.foo, 1);
      assert.deepEqual(data.bar, 2);
      addError("foo", "error");
      addError("bar", "error");
      done();
    };

    await render(<template>
      <Form @data={{hash foo=1 bar=2}} @validate={{validate}} as |form|>
        <form.Field @name="foo" @title="Foo" />
        <form.Field @name="bar" @title="Bar" />
      </Form>
    </template>);

    await formKit().submit();
    await settled();

    assert.form("form").hasErrors({
      foo: "error",
      bar: "error",
    });
  });

  test("@onRegisterApi", async function (assert) {
    let formApi;

    const doneRegister = assert.async();
    const registerApi = (api) => {
      formApi = api;
      doneRegister();
    };

    const doneSubmit = assert.async();
    const submit = (data) => {
      assert.deepEqual(data.foo, 1);
      doneSubmit();
    };

    await render(<template>
      <Form
        @data={{hash foo=1}}
        @onSubmit={{submit}}
        @onRegisterApi={{registerApi}}
        as |form data|
      >
        <div class="bar">{{data.bar}}</div>
      </Form>
    </template>);

    await formApi.set("bar", 2);
    assert.dom(".bar").hasText("2");

    await formApi.reset();
    assert.dom(".bar").hasNoText("2");

    await formApi.submit();
  });

  test("@data", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=1}} as |form data|>
        <div class="foo">{{data.foo}}</div>
      </Form>
    </template>);

    assert.dom(".foo").hasText("1");
  });

  test("@mutable", async function (assert) {
    const data = { foo: 1 };

    await render(<template>
      <Form @mutable={{true}} @data={{data}} as |form|>
        <form.Field @name="foo" @title="Foo" as |field|>
          <field.Input />
        </form.Field>
        <form.Button class="set-foo" @action={{fn form.set "foo" 2}} />
      </Form>
    </template>);

    await click(".set-foo");

    assert.deepEqual(data.foo, 2);
  });

  test("@onReset", async function (assert) {
    const done = assert.async();
    const onReset = (data) => {
      assert.deepEqual(data.bar, 1, "it resets the data to its initial state");
      done();
    };

    await render(<template>
      <Form @data={{hash bar=1}} @onReset={{onReset}} as |form|>
        <form.Field @title="Foo" @name="foo" @validation="required" as |field|>
          <field.Input />
        </form.Field>
        <form.Field @title="Bar" @name="bar" as |field|>
          <field.Input />
        </form.Field>
        <form.Button class="set-bar" @action={{fn form.set "bar" 2}} />
      </Form>
    </template>);

    await click(".set-bar");
    await formKit().submit();

    assert.form().field("bar").hasValue("2");
    assert.form().field("foo").hasError("Required");

    await formKit().reset();

    assert.form().field("foo").hasNoError("it resets the errors");
  });

  test("immutable by default", async function (assert) {
    const data = { foo: 1 };

    await render(<template>
      <Form @data={{data}} as |form|>
        <form.Field @name="foo" @title="Foo" as |field|>
          <field.Input />
        </form.Field>
        <form.Button class="set-foo" @action={{fn form.set "foo" 2}} />
      </Form>
    </template>);

    await click(".set-foo");

    assert.deepEqual(data.foo, 1);
  });

  test("yielded set", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=1}} as |form data|>
        <div class="foo">{{data.foo}}</div>
        <form.Button class="test" @action={{fn form.set "foo" 2}} />
      </Form>
    </template>);

    await click(".test");

    assert.dom(".foo").hasText("2");
  });
});
