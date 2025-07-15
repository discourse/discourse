import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GamificationScore from "../discourse/components/gamification-score";

module(
  "Discourse Gamification | Component | gamification-score",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Scores click link to leaderboard", async function (assert) {
      this.site.default_gamification_leaderboard_id = 1;
      const user = { id: "1", username: "charlie", gamification_score: 1 };

      await render(<template><GamificationScore @model={{user}} /></template>);

      assert.dom(".gamification-score a").exists("scores are not clickable");
    });

    test("Scores show up and are not clickable", async function (assert) {
      const user = { id: "1", username: "charlie", gamification_score: 1 };

      await render(<template><GamificationScore @model={{user}} /></template>);

      assert.dom(".gamification-score").exists("scores not showing up");
      assert.dom(".gamification-score a").doesNotExist("scores are clickable");
    });
  }
);
