import { render } from "@ember/test-helpers";
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

      assert.dom(".user__name").hasText("foo", "the leaderboard rows render");
      assert.dom(".d-skeleton").doesNotExist("no skeleton once resolved");
    });

    test("surfaces an inline error when the fetch fails", async function (assert) {
      pretender.get("/leaderboard", () => response(500, {}));

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: GamificationLeaderboardBlock },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".hero-blocks__block .alert-error")
        .exists("the failure surfaces as an inline error");
    });
  }
);
