import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GamificationLeaderboard from "../discourse/components/gamification-leaderboard";

module(
  "Discourse Gamification | Component | gamification-leaderboard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Display name prioritizes name", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      const model = {
        leaderboard: "",
        personal: "",
        users: [{ username: "id", name: "bob" }],
      };

      await render(
        <template><GamificationLeaderboard @model={{model}} /></template>
      );

      assert.dom(".winner__name").hasText("bob");
    });

    test("Display name prioritizes username", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      const model = {
        leaderboard: "",
        personal: "",
        users: [{ username: "id", name: "bob" }],
      };

      await render(
        <template><GamificationLeaderboard @model={{model}} /></template>
      );

      assert.dom(".winner__name").hasText("id");
    });

    test("Display name prioritizes username when name is empty", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      const model = {
        leaderboard: "",
        personal: "",
        users: [{ username: "id", name: "" }],
      };

      await render(
        <template><GamificationLeaderboard @model={{model}} /></template>
      );

      assert.dom(".winner__name").hasText("id");
    });
  }
);
