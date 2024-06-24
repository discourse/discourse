import { hash } from "@ember/helper";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Field", function (hooks) {
  setupRenderingTest(hooks);

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

  test("@validation", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @validation="required" as |field|>
          <field.Input />
        </form.Field>
      </Form>
    </template>);

    await formKit("form").submit();

    assert.form("form").hasErrors({ foo: ["Required"] });
    assert.form("form").field("foo").hasError("Required");
  });

  test("@validate", async function (assert) {
    const done = assert.async();
    const validate = async (name, value, { addError, data }) => {
      assert.deepEqual(name, "foo", "the callback has the name as param");
      assert.deepEqual(value, "bar", "the callback has the name as param");
      assert.deepEqual(
        data,
        { foo: "bar" },
        "the callback has the data as param"
      );

      addError("foo", "error");

      done();
    };

    await render(<template>
      <Form @data={{hash foo="bar"}} as |form|>
        <form.Field @name="foo" @title="Foo" @validate={{validate}} />
        <form.Submit />
      </Form>
    </template>);

    await click("button");

    assert
      .form("form")
      .hasErrors(
        { foo: ["error"] },
        "the callback has the addError helper as param"
      );
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

  test("@onSet", async function (assert) {
    const done = assert.async();
    const onSet = async (value, { set }) => {
      assert.form("form").field("foo").hasValue("bar");

      await set("foo", "baz");

      assert.form("form").field("foo").hasValue("baz");

      done();
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
