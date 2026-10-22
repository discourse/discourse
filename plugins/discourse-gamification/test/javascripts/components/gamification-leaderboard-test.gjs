import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import GamificationLeaderboard from "discourse/plugins/discourse-gamification/discourse/components/gamification-leaderboard";

module(
  "Discourse Gamification | Component | GamificationLeaderboard",
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
    test("shows the users for the chosen period", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      pretender.get("/leaderboard/3", (request) =>
        response({
          users: [{ username: `${request.queryParams.period}_winner` }],
          personal: null,
        })
      );
      const model = {
        leaderboard: { id: 3, default_period: 0 },
        personal: "",
        users: [{ username: "all_time_winner" }],
      };

      await render(
        <template><GamificationLeaderboard @model={{model}} /></template>
      );

      assert.dom(".winner__name").hasText("all_time_winner");

      const chooser = selectKit(".leaderboard__period-chooser");
      await chooser.expand();
      await chooser.selectRowByValue("weekly");

      assert
        .dom(".winner__name")
        .hasText("weekly_winner", "shows the period's users");
    });
    test("follows the default period of a new leaderboard", async function (assert) {
      pretender.get("/leaderboard/:id", () =>
        response({ users: [{ username: "winner" }], personal: null })
      );
      const model = tracked({
        leaderboard: { id: 3, default_period: 0 },
        personal: "",
        users: [{ username: "winner" }],
      });

      await render(
        <template><GamificationLeaderboard @model={{model.value}} /></template>
      );

      const chooser = selectKit(".leaderboard__period-chooser");
      await chooser.expand();
      await chooser.selectRowByValue("weekly");
      assert.strictEqual(chooser.header().value(), "weekly");

      model.value = {
        leaderboard: { id: 4, default_period: 3 },
        personal: "",
        users: [{ username: "winner" }],
      };
      await rerender();

      assert.strictEqual(
        chooser.header().value(),
        "monthly",
        "resets to the new leaderboard's default"
      );
    });
  }
);
