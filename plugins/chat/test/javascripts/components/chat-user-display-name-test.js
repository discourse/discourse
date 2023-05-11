import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

function displayName() {
  return query(".chat-user-display-name").innerText.trim();
}

module(
  "Discourse Chat | Component | chat-user-display-name | prioritize username in UX",
  function (hooks) {
    setupRenderingTest(hooks);

    test("username and no name", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      this.set("user", { username: "bob", name: null });

      await render(hbs`<ChatUserDisplayName @user={{this.user}} />`);

      assert.strictEqual(displayName(), "bob");
    });

    test("username and name", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      this.set("user", { username: "bob", name: "Bobcat" });

      await render(hbs`<ChatUserDisplayName @user={{this.user}} />`);

      assert.strictEqual(displayName(), "bob — Bobcat");
    });
  }
);

module(
  "Discourse Chat | Component | chat-user-display-name | prioritize name in UX",
  function (hooks) {
    setupRenderingTest(hooks);

    test("no name", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      this.set("user", { username: "bob", name: null });

      await render(hbs`<ChatUserDisplayName @user={{this.user}} />`);

      assert.strictEqual(displayName(), "bob");
    });

    test("name and username", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      this.set("user", { username: "bob", name: "Bobcat" });

      await render(hbs`<ChatUserDisplayName @user={{this.user}} />`);

      assert.strictEqual(displayName(), "Bobcat — bob");
    });
  }
);
