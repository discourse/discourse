import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Controls | Custom",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="custom"
              @name="foo"
              @title="Foo"
              @description="Bar"
              as |field|
            >
              <field.Control>
                <input class="custom-test" />
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__container-title").hasText("Foo (optional)");
      assert.dom(".form-kit__container-description").hasText("Bar");
    });
  }
);
