import { hash } from "@ember/helper";
import {
  fillIn,
  render,
  resetOnerror,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.consoleWarnStub = sinon.stub(console, "error");
  });

  hooks.afterEach(function () {
    this.consoleWarnStub.restore();
  });

  test("@size", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @size={{8}}>
          Test
        </form.Field>
      </Form>
    </template>);

    assert.dom(".form-kit__row .form-kit__col.--col-8").hasText("Test");
  });

  test("@disabled", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
          <field.Input />
        </form.Field>
      </Form>
    </template>);

    assert
      .dom("#control-foo.is-disabled[data-disabled]")
      .exists("it sets the disabled class and data attribute");
  });

  test("@description", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @description="foo foo" as |field|>
          <field.Input />
        </form.Field>
      </Form>
    </template>);

    assert.form().field("foo").hasDescription("foo foo");
  });

  test("invalid @name", async function (assert) {
    setupOnerror((error) => {
      assert.deepEqual(error.message, "@name can't include `.` or `-`.");
    });

    await render(<template>
      <Form as |form|>
        <form.Field @name="foo.bar" @title="Foo" @size={{8}}>
          Test
        </form.Field>
      </Form>
    </template>);

    resetOnerror();
  });

  test("non existing title", async function (assert) {
    setupOnerror((error) => {
      assert.deepEqual(
        error.message,
        "@title is required on `<form.Field />`."
      );
    });

    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @size={{8}}>
          Test
        </form.Field>
      </Form>
    </template>);

    resetOnerror();
  });

  test("@validation", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @validation="required" as |field|>
          <field.Input />
        </form.Field>
        <form.Field @name="bar" @title="Bar" @validation="required" as |field|>
          <field.Input />
        </form.Field>
      </Form>
    </template>);

    await formKit().submit();

    assert.form().hasErrors({ foo: ["Required"], bar: ["Required"] });
    assert.form().field("foo").hasError("Required");
    assert.form().field("bar").hasError("Required");
  });

  test("@validate", async function (assert) {
    const validate = async (name, value, { addError, data }) => {
      assert.deepEqual(name, "foo", "the callback has the name as param");
      assert.deepEqual(value, "bar", "the callback has the name as param");
      assert.deepEqual(
        data,
        { foo: "bar" },
        "the callback has the data as param"
      );

      addError("foo", { title: "Some error", message: "error" });
    };

    await render(<template>
      <Form @data={{hash foo="bar"}} as |form|>
        <form.Field @name="foo" @title="Foo" @validate={{validate}} as |field|>
          <field.Input />
        </form.Field>

        <form.Submit />
      </Form>
    </template>);

    await formKit().submit();

    assert
      .form()
      .field("foo")
      .hasError("error", "the callback has the addError helper as param");
  });

  test("@showTitle", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field
          @name="foo"
          @title="Foo"
          @showTitle={{false}}
          as |field|
        ><field.Input /></form.Field>
      </Form>
    </template>);

    assert.dom(".form-kit__container-title").doesNotExist();
  });

  test("@format full", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field
          @name="foo"
          @title="Foo"
          @format="full"
          as |field|
        ><field.Input /></form.Field>
      </Form>
    </template>);

    assert
      .dom(".form-kit__field.--full")
      .exists("it applies the --full class to the field");
  });

  test("@onSet", async function (assert) {
    const onSetWasCalled = assert.async();

    const onSet = async (value, { set }) => {
      assert.form().field("foo").hasValue("bar");

      await set("foo", "baz");
      await settled();

      assert.form().field("foo").hasValue("baz");
      onSetWasCalled();
    };

    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @onSet={{onSet}} as |field|>
          <field.Input />
        </form.Field>
      </Form>
    </template>);

    await fillIn("input", "bar");
  });
});
