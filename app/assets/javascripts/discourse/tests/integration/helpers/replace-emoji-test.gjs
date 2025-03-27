import { htmlSafe } from "@ember/template";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | replace-emoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it replaces the emoji", async function (assert) {
    await render(
      <template>
        <span>{{replaceEmoji "some text :heart:"}}</span>
      </template>
    );

    assert.dom(`span`).includesText("some text");
    assert.dom(`.emoji[title="heart"]`).exists();
  });

  test("it escapes the text", async function (assert) {
    await render(
      <template>
        <span>{{replaceEmoji "<style>body: {background: red;}</style>"}}</span>
      </template>
    );

    assert.dom(`span`).hasText("<style>body: {background: red;}</style>");
  });

  test("it renders html-safe text", async function (assert) {
    await render(
      <template>
        <span>{{replaceEmoji (htmlSafe "safe text")}}</span>
      </template>
    );

    assert.dom(`span`).hasText("safe text");
  });
});
