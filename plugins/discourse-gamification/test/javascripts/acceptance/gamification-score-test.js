import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Gamification | User Card | Show Gamification Score",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      const cardResponse = cloneJSON(userFixtures["/u/charlie/card.json"]);
      cardResponse.user.gamification_score = 10;
      server.get("/u/charlie/card.json", () => helper.response(cardResponse));
    });

    test("user card gamification score - score is present", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click(".topic-map__users-trigger");
      await click('a[data-user-card="charlie"]');

      assert
        .dom(".user-card .gamification-score")
        .hasText("Cheers 10", "user card has gamification score");
    });
  }
);

acceptance(
  "Discourse Gamification | User Metadata | Show Gamification Score",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      const userResponse = cloneJSON(fixturesByUrl["/u/charlie.json"]);
      userResponse.user.gamification_score = 10;

      server.get("/u/charlie.json", () => helper.response(userResponse));
    });

    test("user profile gamification score - score is present", async function (assert) {
      await visit("/u/charlie/summary");

      assert
        .dom(".details .secondary .gamification-score")
        .hasText("10", "user metadata has gamification score");
    });
  }
);
