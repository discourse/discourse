import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module } from "qunit";

function displayName() {
  return query(".chat-user-display-name").innerText.trim();
}

module(
  "Discourse Chat | Component | chat-user-display-name | prioritize username in UX",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("username and no name", {
      template: hbs`{{chat-user-display-name user=user}}`,

      async beforeEach() {
        this.siteSettings.prioritize_username_in_ux = true;
        this.set("user", { username: "bob", name: null });
      },

      async test(assert) {
        assert.equal(displayName(), "bob");
      },
    });

    componentTest("username and name", {
      template: hbs`{{chat-user-display-name user=user}}`,

      async beforeEach() {
        this.siteSettings.prioritize_username_in_ux = true;
        this.set("user", { username: "bob", name: "Bobcat" });
      },

      async test(assert) {
        assert.equal(displayName(), "bob — Bobcat");
      },
    });
  }
);

module(
  "Discourse Chat | Component | chat-user-display-name | prioritize name in UX",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("no name", {
      template: hbs`{{chat-user-display-name user=user}}`,

      async beforeEach() {
        this.siteSettings.prioritize_username_in_ux = false;
        this.set("user", { username: "bob", name: null });
      },

      async test(assert) {
        assert.equal(displayName(), "bob");
      },
    });

    componentTest("name and username", {
      template: hbs`{{chat-user-display-name user=user}}`,

      async beforeEach() {
        this.siteSettings.prioritize_username_in_ux = false;
        this.set("user", { username: "bob", name: "Bobcat" });
      },

      async test(assert) {
        assert.equal(displayName(), "Bobcat — bob");
      },
    });
  }
);
