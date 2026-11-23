import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserField from "discourse/components/user-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | UserFields | Number", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a number input labelled with the field name", async function (assert) {
    const field = {
      id: 1,
      name: "Age",
      description: "How old are you?",
      field_type: "number",
      required: false,
    };
    const userField = { value: null };

    await render(
      <template>
        <UserField @field={{field}} @value={{userField.value}} />
      </template>
    );

    assert
      .dom(".user-field.number input")
      .hasAttribute("type", "number", "renders a number input")
      .hasAttribute("step", "any", "accepts decimals");
    assert
      .dom(".user-field.number .control-label")
      .includesText("Age", "renders the field name as the label");

    await fillIn(".user-field.number input", "42");

    assert
      .dom(".user-field.number input")
      .hasValue("42", "keeps the entered number");
  });
});
