import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Layout | Section",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Section class="something">Test</form.Section>
          </Form>
        </template>
      );

      assert.dom(".form-kit__section.something").hasText("Test");
    });

    test("@title", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Section @title="Title">Test</form.Section>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__section .form-kit__section-title")
        .hasText("Title");
    });

    test("@subtitle", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Section @subtitle="Subtitle">Test</form.Section>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__section .form-kit__section-subtitle")
        .hasText("Subtitle");
    });
  }
);
