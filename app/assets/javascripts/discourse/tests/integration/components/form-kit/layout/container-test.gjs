import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Layout | Container",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Container class="something">Test</form.Container>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__container.something .form-kit__container-content")
        .hasText("Test");
    });

    test("@title", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Container @title="Title">Test</form.Container>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__container .form-kit__container-title")
        .hasText("Title");
    });

    test("@subtitle", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Container @subtitle="Subtitle">Test</form.Container>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__container .form-kit__container-subtitle")
        .hasText("Subtitle");
    });

    test("@format", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Container @format="large">Test</form.Container>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__container .form-kit__container-content.--large")
        .exists();
    });

    test("@direction", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Container @direction="column">Test</form.Container>
          </Form>
        </template>
      );

      assert.dom(".form-kit__container.--column").exists();
    });
  }
);
