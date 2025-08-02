import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import MinimalGamificationLeaderboard from "../discourse/components/minimal-gamification-leaderboard";

module(
  "Discourse Gamification | Component | minimal-gamification-leaderboard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("regular leaderboard endpoint", async function (assert) {
      pretender.get("/leaderboard", () =>
        response({
          leaderboard: "",
          personal: "",
          users: [{ id: 1, username: "foo" }],
        })
      );

      await render(<template><MinimalGamificationLeaderboard /></template>);

      assert.dom(".user__name").hasText("foo");
    });

    test("leaderboard by id and with custom user count", async function (assert) {
      pretender.get("/leaderboard/3", ({ queryParams }) => {
        assert.strictEqual(queryParams.user_limit, "5");

        return response({
          leaderboard: "",
          personal: "",
          users: [{ id: 1, username: "foo" }],
        });
      });

      await render(
        <template>
          <MinimalGamificationLeaderboard @id="3" @count="5" />
        </template>
      );

      assert.dom(".user__name").hasText("foo");
    });
  }
);
