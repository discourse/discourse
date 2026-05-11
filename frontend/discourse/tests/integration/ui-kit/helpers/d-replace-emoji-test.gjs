import { trustHTML } from "@ember/template";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

module("Integration | ui-kit | Helper | dReplaceEmoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it replaces the emoji", async function (assert) {
    await render(
      <template>
        <span>{{dReplaceEmoji "some text :heart:"}}</span>
      </template>
    );

    assert.dom(`span`).includesText("some text");
    assert.dom(`.emoji[title="heart"]`).exists();
  });

  test("it escapes the text", async function (assert) {
    await render(
      <template>
        <span>{{dReplaceEmoji "<style>body: {background: red;}</style>"}}</span>
      </template>
    );

    assert.dom(`span`).hasText("<style>body: {background: red;}</style>");
  });

  test("it renders html-safe text", async function (assert) {
    await render(
      <template>
        <span>{{dReplaceEmoji (trustHTML "safe text")}}</span>
      </template>
    );

    assert.dom(`span`).hasText("safe text");
  });
});
