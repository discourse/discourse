import { array, concat, fn, hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FormKit | Collection", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
        <form.Collection @name="foo" as |collection|>
          <collection.Field @name="bar" @title="Bar" as |field|>
            <field.Input />
          </collection.Field>
        </form.Collection>
      </Form>
    </template>);

    assert.form().field("foo.0.bar").hasValue("1");
    assert.form().field("foo.1.bar").hasValue("2");
  });

  test("remove", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
        <form.Collection @name="foo" as |collection index|>
          <collection.Field @name="bar" @title="Bar" as |field|>
            <field.Input />
            <form.Button
              class={{concat "remove-" index}}
              @action={{fn collection.remove index}}
            >Remove</form.Button>
          </collection.Field>
        </form.Collection>
      </Form>
    </template>);

    assert.form().field("foo.0.bar").hasValue("1");
    assert.form().field("foo.1.bar").hasValue("2");

    await click(".remove-1");

    assert.form().field("foo.0.bar").hasValue("1");
    assert.form().field("foo.1.bar").doesNotExist();
  });
});
