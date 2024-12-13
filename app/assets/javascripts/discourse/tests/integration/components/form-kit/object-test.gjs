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
      <Form @data={{hash foo=(hash bar=(hash baz=1 bol=2))}} as |form|>
        <form.Object @name="foo" as |parentObject|>
          <parentObject.Object @name="bar" as |childObject name|>
            <childObject.Field @name={{name}} @title={{name}} as |field|>
              <field.Input />
            </childObject.Field>
          </parentObject.Object>
        </form.Object>
      </Form>
    </template>);

    assert.form().field("foo.bar.baz").hasValue("1");
    assert.form().field("foo.bar.bol").hasValue("2");

    await formKit().field("foo.bar.bol").fillIn("2");

    assert.form().field("foo.bar.bol").hasValue("2");
  });

  test("nested collection", async function (assert) {
    await render(<template>
      <Form
        @data={{hash foo=(hash bar=(array (hash baz=1) (hash baz=2)))}}
        as |form|
      >
        <form.Object @name="foo" as |parentObject|>
          <parentObject.Collection @name="bar" as |collection index|>
            <collection.Field @name="baz" @title="baz" as |field|>
              <field.Input />
            </collection.Field>
            <form.Button
              class={{concat "remove-" index}}
              @action={{fn collection.remove index}}
            >Remove</form.Button>
          </parentObject.Collection>
        </form.Object>
      </Form>
    </template>);

    assert.form().field("foo.bar.0.baz").hasValue("1");
    assert.form().field("foo.bar.1.baz").hasValue("2");

    await click(".remove-1");

    assert.form().field("foo.bar.0.baz").hasValue("1");
    assert.form().field("foo.bar.1.baz").doesNotExist();

    await formKit().field("foo.bar.0.baz").fillIn("2");

    assert.form().field("foo.bar.0.baz").hasValue("2");
  });
});
