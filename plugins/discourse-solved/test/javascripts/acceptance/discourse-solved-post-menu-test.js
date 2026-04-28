import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance("Post Menu | Accept and Unaccept", function (needs) {
  needs.user({ admin: true });

  needs.settings({
    solved_enabled: true,
    allow_solved_on_all_topics: true,
  });

  needs.pretender((server, helper) => {
    server.post("/solution/accept", () =>
      helper.response(
        postStreamWithAcceptedAnswerExcerpt(null).accepted_answers
      )
    );
    server.post("/solution/unaccept", () => helper.response([]));

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

  test("hides/shows the accepting user based on setting", async function (assert) {
    await visit("/t/without-excerpt/12");

    assert
      .dom("#post_2 .post-action-menu__solved-accepted")
      .exists("Unaccept button is visible")
      .hasText(i18n("solved.solution"), "Unaccept button has correct text");

    assert
      .dom(
        "#post_2 .fk-d-tooltip__trigger-container .post-action-menu__solved-accepted"
      )
      .doesNotExist();

    this.siteSettings.show_who_marked_solved = true;
    await visit("/t/without-excerpt/12");

    assert
      .dom(
        "#post_2 .fk-d-tooltip__trigger-container .post-action-menu__solved-accepted"
      )
      .exists();

    await triggerEvent(
      "#post_2 .post-action-menu__solved-accepted",
      "pointermove"
    );

    assert
      .dom(
        "#post_2 .fk-d-tooltip__content[data-identifier='post-action-menu__solved-accepted-tooltip']"
      )
      .hasText(i18n("solved.marked_solved_by", { user: "tomtom" }));

    this.siteSettings.display_name_on_posts = true;
    await visit("/t/without-excerpt/12");

    assert
      .dom(
        "#post_2 .fk-d-tooltip__trigger-container .post-action-menu__solved-accepted"
      )
      .exists();

    await triggerEvent(
      "#post_2 .post-action-menu__solved-accepted",
      "pointermove"
    );

    assert
      .dom(
        "#post_2 .fk-d-tooltip__content[data-identifier='post-action-menu__solved-accepted-tooltip']"
      )
      .hasText(i18n("solved.marked_solved_by", { user: "Tomtom" }));
  });
});
