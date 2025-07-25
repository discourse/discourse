import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GamificationLeaderboardRow from "../discourse/components/gamification-leaderboard-row";

module(
  "Discourse Gamification | Component | gamification-leaderboard-row",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Display name prioritizes name", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      const rank = { username: "id", name: "bob" };

      await render(
        <template><GamificationLeaderboardRow @rank={{rank}} /></template>
      );

      assert.dom(".user__name").hasText("bob");
    });

    test("Display name prioritizes username", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      const rank = { username: "id", name: "bob" };

      await render(
        <template><GamificationLeaderboardRow @rank={{rank}} /></template>
      );

      assert.dom(".user__name").hasText("id");
    });

    test("Display name prioritizes username when name is empty", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = false;
      const rank = { username: "id", name: "" };

      await render(
        <template><GamificationLeaderboardRow @rank={{rank}} /></template>
      );

      assert.dom(".user__name").hasText("id");
    });
  }
);
