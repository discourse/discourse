import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import tonableEmojiTitle from "discourse/plugins/chat/discourse/helpers/tonable-emoji-title";

module(
  "Discourse Chat | Unit | Helpers | tonable-emoji-title",
  function (hooks) {
    setupRenderingTest(hooks);

    test("When emoji is not tonable", async function (assert) {
      const emoji = { name: "foo", tonable: false };
      const diversity = 1;
      await render(<template>
        <span>{{tonableEmojiTitle emoji diversity}}</span>
      </template>);

      assert.dom("span").hasText(":foo:");
    });

    test("When emoji is tonable and diversity is 1", async function (assert) {
      const emoji = { name: "foo", tonable: true };
      const diversity = 1;
      await render(<template>
        <span>{{tonableEmojiTitle emoji diversity}}</span>
      </template>);

      assert.dom("span").hasText(":foo:");
    });

    test("When emoji is tonable and diversity is greater than 1", async function (assert) {
      const emoji = { name: "foo", tonable: true };
      const diversity = 2;
      await render(<template>
        <span>{{tonableEmojiTitle emoji diversity}}</span>
      </template>);

      assert.dom("span").hasText(":foo:t2:");
    });
  }
);
