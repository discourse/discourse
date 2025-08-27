import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Discourse Voting Plugin | /activity/votes | empty state",
  function (needs) {
    const currentUser = "eviltrout";
    const anotherUser = "charlie";

    needs.user();

    needs.pretender((server, helper) => {
      const emptyResponse = { topic_list: { topics: [] } };

      server.get(`/topics/voted-by/${currentUser}.json`, () => {
        return helper.response(emptyResponse);
      });

      server.get(`/topics/voted-by/${anotherUser}.json`, () => {
        return helper.response(emptyResponse);
      });
    });

    test("When looking at the own activity page", async function (assert) {
      await visit(`/u/${currentUser}/activity/votes`);
      assert
        .dom(".empty-state .empty-state__title")
        .hasText(i18n("topic_voting.no_votes_title_self"));
    });

    test("When looking at another user's activity page", async function (assert) {
      await visit(`/u/${anotherUser}/activity/votes`);
      assert
        .dom(".empty-state .empty-state__title")
        .hasText(
          i18n("topic_voting.no_votes_title_others", { username: anotherUser })
        );
    });
  }
);
