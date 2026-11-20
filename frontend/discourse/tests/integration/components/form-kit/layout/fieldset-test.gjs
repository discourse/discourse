import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Layout | Fieldset",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Fieldset
              @description="Description"
              @name="a-fieldset"
              @title="Title"
            >
              Yielded content
            </form.Fieldset>
          </Form>
        </template>
      );

      assert
        .form()
        .fieldset("a-fieldset")
        .hasTitle("Title", "it renders a title");
      assert
        .form()
        .fieldset("a-fieldset")
        .hasDescription("Description", "it renders a description");
      assert
        .form()
        .fieldset("a-fieldset")
        .includesText("Yielded content", "it yields its content");
    });
  }
);
