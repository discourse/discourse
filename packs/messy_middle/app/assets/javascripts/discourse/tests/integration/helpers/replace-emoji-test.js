import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Helper | replace-emoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it replaces the emoji", async function (assert) {
    await render(hbs`<span>{{replace-emoji "some text :heart:"}}</span>`);

    assert.dom(`span`).includesText("some text");
    assert.dom(`.emoji[title="heart"]`).exists();
  });

  test("it escapes the text", async function (assert) {
    await render(
      hbs`<span>{{replace-emoji "<style>body: {background: red;}</style>"}}</span>`
    );

    assert.dom(`span`).hasText("<style>body: {background: red;}</style>");
  });

  test("it renders html-safe text", async function (assert) {
    await render(hbs`<span>{{replace-emoji (html-safe "safe text")}}</span>`);

    assert.dom(`span`).hasText("safe text");
  });
});
