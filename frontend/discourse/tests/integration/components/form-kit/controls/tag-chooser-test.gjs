import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | FormKit | Controls | TagChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.TagChooser />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-tag-chooser").exists();

      const sk = selectKit(".form-kit__control-tag-chooser");
      await sk.expand();
      await sk.selectRowByName("monkey");

      await formKit().submit();

      assert.strictEqual(data.foo[0].name, "monkey");
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
              <field.TagChooser />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-tag-chooser.is-disabled").exists();
    });
  }
);
