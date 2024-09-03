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

  test("@label", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Submit @label="cancel" />
      </Form>
    </template>);

    assert
      .dom(".form-kit__button")
      .hasText(I18n.t("cancel"), "it allows to override the label");
  });

  test("@isLoading", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Submit @label="cancel" @isLoading={{true}} />
      </Form>
    </template>);

    assert.dom(".form-kit__button .d-icon-spinner").exists();
  });
});
