import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Discourse Solved Plugin | activity/solved | empty state",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/solution/by_user.json", () =>
        helper.response({ user_solved_posts: [] })
      );
    });

    test("When looking at own activity", async function (assert) {
      await visit(`/u/eviltrout/activity/solved`);

      assert
        .dom(".empty-state .empty-state__title")
        .hasText(i18n("solved.no_solved_topics_title"));
      assert
        .dom(".empty-state .empty-state__body")
        .hasText(i18n("solved.no_solved_topics_body"));
    });

    test("When looking at another user's activity", async function (assert) {
      await visit(`/u/charlie/activity/solved`);

      assert.dom(".empty-state .empty-state__title").hasText(
        i18n("solved.no_solved_topics_title_others", {
          username: "charlie",
        })
      );
      assert.dom(".empty-state .empty-state__body").doesNotExist();
    });
  }
);
