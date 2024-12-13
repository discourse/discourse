import { array, concat, fn, hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Object", function (hooks) {
  setupRenderingTest(hooks);

  test("field", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=(hash bar=1 baz=2)}} as |form|>
        <form.Object @name="foo" as |object name|>
          <object.Field @name={{name}} @title={{name}} as |field|>
            <field.Input />
          </object.Field>
        </form.Object>
      </Form>
    </template>);

    assert.form().field("foo.bar").hasValue("1");
    assert.form().field("foo.baz").hasValue("2");
  });

  test("nested object", async function (assert) {
    await render(<template>
      <Form
        @data={{hash one=(hash two=(hash three=(hash foo=1 bar=2)))}}
        as |form|
      >
        <form.Object @name="one" as |one|>
          <one.Object @name="two" as |two|>
            <two.Object @name="three" as |three name|>
              <three.Field @name={{name}} @title={{name}} as |field|>
                <field.Input />
              </three.Field>
            </two.Object>
          </one.Object>
        </form.Object>
      </Form>
    </template>);

    assert.form().field("one.two.three.foo").hasValue("1");
    assert.form().field("one.two.three.bar").hasValue("2");

    await formKit().field("one.two.three.foo").fillIn("2");

    assert.form().field("one.two.three.foo").hasValue("2");
  });

  test("nested collection", async function (assert) {
    await render(<template>
      <Form
        @data={{hash one=(hash two=(array (hash foo=1) (hash foo=2)))}}
        as |form|
      >
        <form.Object @name="one" as |one|>
          <one.Collection @name="two" as |two twoIndex|>
            <two.Field @name="foo" @title="foo" as |field|>
              <field.Input />
            </two.Field>
            <form.Button
              class={{concat "remove-" twoIndex}}
              @action={{fn two.remove twoIndex}}
            >Remove</form.Button>
          </one.Collection>
        </form.Object>
      </Form>
    </template>);

    assert.form().field("one.two.0.foo").hasValue("1");
    assert.form().field("one.two.1.foo").hasValue("2");

    await click(".remove-1");

    assert.form().field("one.two.0.foo").hasValue("1");
    assert.form().field("one.two.1.foo").doesNotExist();

    await formKit().field("one.two.0.foo").fillIn("2");

    assert.form().field("one.two.0.foo").hasValue("2");
  });
});
