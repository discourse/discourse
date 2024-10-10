import { array, fn, hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Form", function (hooks) {
  setupRenderingTest(hooks);

  test("@onSubmit", async function (assert) {
    const onSubmit = (data) => {
      assert.deepEqual(data.foo, 1);
    };

    await render(<template>
      <Form @data={{hash foo=1}} @onSubmit={{onSubmit}} />
    </template>);

    await formKit().submit();
  });

  test("addItemToCollection", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
        <form.Button
          @action={{fn form.addItemToCollection "foo" (hash bar=3)}}
        >Add</form.Button>

        <form.Collection @name="foo" as |collection|>
          <collection.Field @name="bar" @title="Bar" as |field|>
            <field.Input />
          </collection.Field>
        </form.Collection>
      </Form>
    </template>);

    await click("button");

    assert.form().field("foo.0.bar").hasValue("1");
    assert.form().field("foo.1.bar").hasValue("2");
    assert.form().field("foo.2.bar").hasValue("3");
  });

  test("@validate", async function (assert) {
    const validate = async (data, { addError }) => {
      assert.deepEqual(data.foo, 1);
      assert.deepEqual(data.bar, 2);
      addError("foo", { title: "Foo", message: "incorrect type" });
      addError("foo", { title: "Foo", message: "required" });
      addError("bar", { title: "Bar", message: "error" });
    };

    await render(<template>
      <Form @data={{hash foo=1 bar=2}} @validate={{validate}} as |form|>
        <form.Field @name="foo" @title="Foo" />
        <form.Field @name="bar" @title="Bar" />
      </Form>
    </template>);

    await formKit().submit();

    assert.form().hasErrors({
      foo: "incorrect type, required",
      bar: "error",
    });
  });

  test("@validateOn", async function (assert) {
    const data = { foo: "test" };

    await render(<template>
      <Form @data={{data}} as |form|>
        <form.Field @name="foo" @title="Foo" @validation="required" as |field|>
          <field.Input />
        </form.Field>
        <form.Field @name="bar" @title="Bar" @validation="required" as |field|>
          <field.Input />
        </form.Field>
        <form.Submit />
      </Form>
    </template>);

    await formKit().field("foo").fillIn("");

    assert.form().field("foo").hasNoErrors();

    await formKit().submit();

    assert.form().field("foo").hasError("Required");
    assert.form().field("bar").hasError("Required");
    assert.form().hasErrors({
      foo: "Required",
      bar: "Required",
    });

    await formKit().field("foo").fillIn("t");

    assert.form().field("foo").hasNoErrors();
    assert.form().field("bar").hasError("Required");
    assert.form().hasErrors({
      bar: "Required",
    });
  });

  test("@onRegisterApi", async function (assert) {
    let formApi;
    let model = { foo: 1 };

    const registerApi = (api) => {
      formApi = api;
    };

    const submit = (x) => {
      model = x;
      assert.deepEqual(model.foo, 1);
    };

    await render(<template>
      <Form
        @data={{model}}
        @onSubmit={{submit}}
        @onRegisterApi={{registerApi}}
        as |form data|
      >
        <div class="bar">{{data.bar}}</div>
      </Form>
    </template>);

    await formApi.set("bar", 2);
    await formApi.submit();

    assert.dom(".bar").hasText("2");

    await formApi.set("bar", 1);
    await formApi.reset();
    await formApi.submit();

    assert.dom(".bar").hasText("2");

    formApi.addError("bar", { title: "Bar", message: "error_foo" });
    // assert on the next tick
    setTimeout(() => {
      assert.form().hasErrors({ bar: "error_foo" });
    }, 0);
  });

  test("@data", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=1}} as |form data|>
        <div class="foo">{{data.foo}}</div>
      </Form>
    </template>);

    assert.dom(".foo").hasText("1");
  });

  test("@onReset", async function (assert) {
    const done = assert.async();
    const onReset = async () => {
      assert
        .form()
        .field("bar")
        .hasValue("1", "it resets the data to its initial state");
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
    await formKit().field("foo").fillIn("");

    await formKit().submit();

    assert.form().field("bar").hasValue("2");
    assert.form().field("foo").hasError("Required");

    await formKit().reset();

    assert.form().field("foo").hasNoErrors("it resets the errors");
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

  test("yielded setProperties", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=1 bar=1}} as |form data|>
        <div class="foo">{{data.foo}}</div>
        <div class="bar">{{data.bar}}</div>
        <form.Button
          class="test"
          @action={{fn form.setProperties (hash foo=2 bar=2)}}
        />
      </Form>
    </template>);

    await click(".test");

    assert.dom(".foo").hasText("2");
    assert.dom(".bar").hasText("2");
  });

  test("reset virtual errors", async function (assert) {
    let validatedOnce = false;
    const validate = async (data, { removeError, addError }) => {
      if (!validatedOnce) {
        addError("foo", { title: "Foo", message: "error" });

        validatedOnce = true;
      } else {
        removeError("foo");
      }
    };

    await render(<template>
      <Form @validate={{validate}} as |form|>
        <form.Submit />
      </Form>
    </template>);

    await formKit().submit();

    assert.form().hasErrors({ foo: "error" });

    await formKit().submit();

    assert.form().hasNoErrors();
  });
});
