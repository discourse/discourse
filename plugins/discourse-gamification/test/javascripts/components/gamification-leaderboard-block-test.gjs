import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import GamificationLeaderboardBlock from "../discourse/blocks/gamification-leaderboard";

// The reserved-space skeleton + the loading transition are covered generically
// by the core block-data integration tests; here we verify the block resolves
// the leaderboard through the data layer and renders it.
module(
  "Discourse Gamification | Block | gamification-leaderboard",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      resetBlockData();
    });

    test("renders the leaderboard from the data layer", async function (assert) {
      pretender.get("/leaderboard", () =>
        response({
          leaderboard: "",
          personal: "",
          users: [{ id: 1, username: "foo" }],
        })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: GamificationLeaderboardBlock },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".gamification-block-leaderboard__name")
        .hasText("foo", "the leaderboard rows render");
      assert
        .dom(".d-block-panel__title")
        .hasText("Leaderboard", "without a name the panel shows the default");
      assert
        .dom(".d-block-panel__footer .d-block-panel__link")
        .hasText("View leaderboard", "the view all link shows by default");
    });

    test("titles the panel with the leaderboard's name", async function (assert) {
      pretender.get("/leaderboard", () =>
        response({
          leaderboard: { id: 3, name: "Top helpers" },
          personal: "",
          users: [{ id: 1, username: "foo" }],
        })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: GamificationLeaderboardBlock },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".d-block-panel__title").hasText("Top helpers");
      assert.dom(".d-skeleton").doesNotExist("no skeleton once resolved");
    });

    test("shows the empty state when nobody has scored", async function (assert) {
      pretender.get("/leaderboard", () =>
        response({ leaderboard: "", personal: "", users: [] })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: GamificationLeaderboardBlock },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".d-block-panel__empty").hasText("No scores yet");
      assert.dom(".gamification-block-leaderboard__list").doesNotExist();
    });

    test("shows an error with a retry that fetches again", async function (assert) {
      let fail = true;
      pretender.get("/leaderboard", () =>
        fail
          ? response(500, {})
          : response({
              leaderboard: "",
              personal: "",
              users: [{ id: 1, username: "foo" }],
            })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: GamificationLeaderboardBlock },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".hero-blocks__block .d-block-panel__error")
        .exists("the failure surfaces in the panel");

      fail = false;
      await click(".d-block-panel__retry");

      assert
        .dom(".gamification-block-leaderboard__name")
        .hasText("foo", "retrying fetches the leaderboard again");
    });
  }
);
