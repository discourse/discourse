import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

const CONTENT_DIV_SELECTOR = "li > a > div";

module(
  "Integration | Component | Widget | quick-access-item",
  function (hooks) {
    setupRenderingTest(hooks);

    test("content attribute is escaped", async function (assert) {
      this.set("args", { content: "<b>bold</b>" });

      await render(
        hbs`<MountWidget @widget="quick-access-item" @args={{this.args}} />`
      );

      const contentDiv = query(CONTENT_DIV_SELECTOR);
      assert.strictEqual(contentDiv.innerText, "<b>bold</b>");
    });

    test("escapedContent attribute is not escaped", async function (assert) {
      this.set("args", { escapedContent: "&quot;quote&quot;" });

      await render(
        hbs`<MountWidget @widget="quick-access-item" @args={{this.args}} />`
      );

      const contentDiv = query(CONTENT_DIV_SELECTOR);
      assert.strictEqual(contentDiv.innerText, '"quote"');
    });

    test("Renders the notification content with no username when username is not present", async function (assert) {
      this.set("args", {
        content: "content",
        username: undefined,
      });

      await render(
        hbs`<MountWidget @widget="quick-access-item" @args={{this.args}} />`
      );

      const contentDiv = query(CONTENT_DIV_SELECTOR);
      const usernameSpan = query("li a div span");
      assert.strictEqual(contentDiv.innerText, "content");
      assert.strictEqual(usernameSpan.innerText, "");
    });
  }
);
