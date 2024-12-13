import { array, concat, fn, hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Collection", function (hooks) {
  setupRenderingTest(hooks);

  test("@tagName", async function (assert) {
    await render(<template>
      <Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
        <form.Collection @name="foo" @tagName="tr" />
      </Form>
    </template>);

    assert.dom("tr.form-kit__collection").exists();
  });

  test("field", async function (assert) {
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

  test("nested object", async function (assert) {
    await render(<template>
      <Form
        @data={{hash
          foo=(array (hash bar=(hash baz=1)) (hash bar=(hash baz=2)))
        }}
        as |form|
      >
        <form.Collection @name="foo" as |collection index|>
          <collection.Object @name="bar" as |object|>
            <object.Field @name="baz" @title="Baz" as |field|>
              <field.Input />
              <form.Button
                class={{concat "remove-" index}}
                @action={{fn collection.remove index}}
              >Remove</form.Button>
            </object.Field>
          </collection.Object>
        </form.Collection>
      </Form>
    </template>);

    assert.form().field("foo.0.bar.baz").hasValue("1");
    assert.form().field("foo.1.bar.baz").hasValue("2");

    await click(".remove-1");

    assert.form().field("foo.0.bar.baz").hasValue("1");
    assert.form().field("foo.1.bar.baz").doesNotExist();

    await formKit().field("foo.0.bar.baz").fillIn("2");

    assert.form().field("foo.0.bar.baz").hasValue("2");
  });

  test("nested collection", async function (assert) {
    await render(<template>
      <Form
        @data={{hash
          foo=(array
            (hash bar=(array (hash baz=1))) (hash bar=(array (hash baz=2)))
          )
        }}
        as |form|
      >
        <form.Collection @name="foo" as |parent parentIndex|>
          <parent.Collection @name="bar" as |child childIndex|>
            <child.Field @name="baz" @title="Baz" as |field|>
              <field.Input />
              <form.Button
                class={{concat "remove-" parentIndex "-" childIndex}}
                @action={{fn child.remove childIndex}}
              >Remove</form.Button>
            </child.Field>
          </parent.Collection>
        </form.Collection>
      </Form>
    </template>);

    assert.form().field("foo.0.bar.0.baz").hasValue("1");
    assert.form().field("foo.1.bar.0.baz").hasValue("2");

    await click(".remove-1-0");

    assert.form().field("foo.0.bar.0.baz").hasValue("1");
    assert.form().field("foo.1.bar.0.baz").doesNotExist();

    await formKit().field("foo.0.bar.0.baz").fillIn("2");

    assert.form().field("foo.0.bar.0.baz").hasValue("2");
  });
});
