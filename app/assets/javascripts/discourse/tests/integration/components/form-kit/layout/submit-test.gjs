import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

module("Integration | Component | FormKit | Layout | Submit", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    let value;
    const done = assert.async();
    const submit = () => {
      value = 1;
      done();
    };

    await render(<template>
      <Form @onSubmit={{submit}} as |form|>
        <form.Submit />
      </Form>
    </template>);

    await click("button");

    assert.dom(".form-kit__button.btn-primary").hasText(I18n.t("submit"));
    assert.deepEqual(value, 1);
  });
});
