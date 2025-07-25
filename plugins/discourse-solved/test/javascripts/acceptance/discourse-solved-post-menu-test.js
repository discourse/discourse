import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance(
  "Discourse Solved | Post Menu | Accept and Unaccept",
  function (needs) {
    needs.user({ admin: true });

    needs.settings({
      solved_enabled: true,
      allow_solved_on_all_topics: true,
    });

    needs.pretender((server, helper) => {
      server.post("/solution/accept", () =>
        helper.response(
          postStreamWithAcceptedAnswerExcerpt(null).accepted_answer
        )
      );
      server.post("/solution/unaccept", () =>
        helper.response({ success: "OK" })
      );

      server.get("/t/12.json", () =>
        helper.response(postStreamWithAcceptedAnswerExcerpt(null))
      );
    });

    test("accepting and unaccepting a post works", async function (assert) {
      await visit("/t/without-excerpt/12");

      assert
        .dom("#post_2 .post-action-menu__solved-accepted")
        .exists("Unaccept button is visible")
        .hasText(i18n("solved.solution"), "Unaccept button has correct text");

      await click("#post_2 .post-action-menu__solved-accepted");

      assert
        .dom("#post_2 .post-action-menu__solved-unaccepted")
        .exists("Accept button is visible");

      await click("#post_2 .post-action-menu__solved-unaccepted");

      assert
        .dom("#post_2 .post-action-menu__solved-accepted")
        .exists("Unaccept button is visible again");
    });
  }
);
