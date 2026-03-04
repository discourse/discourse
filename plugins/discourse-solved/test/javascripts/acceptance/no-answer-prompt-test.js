import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { topicWithNoAnswer } from "../helpers/discourse-solved-helpers";

acceptance("Discourse Solved - No Answer Prompt", function (needs) {
  needs.user({ id: 1 });
  needs.settings({
    solved_enabled: true,
    allow_solved_on_all_topics: true,
  });

  needs.hooks.beforeEach(function () {
    pretender.get("/t/100.json", () => response(topicWithNoAnswer(1)));
    pretender.post("/solution/accept", () =>
      response({
        success: "OK",
        post_number: 2,
        username: "helper",
        excerpt: "<p>Here is a potential answer</p>",
      })
    );
  });

  test("hides the no answer prompt when clicking the solution button", async function (assert) {
    await visit("/t/test-topic-no-answer/100");

    assert
      .dom(".topic-navigation-popup")
      .exists("no answer prompt is displayed");

    await click(".post-action-menu__solved-unaccepted");

    assert
      .dom(".topic-navigation-popup")
      .doesNotExist("no answer prompt is hidden after accepting solution");
  });

  test("shows confetti when accepting a solution", async function (assert) {
    await visit("/t/test-topic-no-answer/100");

    assert.dom(".solved-confetti").doesNotExist("confetti is not shown yet");

    await click(".post-action-menu__solved-unaccepted");

    assert.dom(".solved-confetti").exists("confetti is shown after accepting");
  });

  test("does not show confetti when user prefers reduced motion", async function (assert) {
    const originalMatchMedia = window.matchMedia;

    sinon.stub(window, "matchMedia").callsFake((query) => {
      const result = originalMatchMedia.call(window, query);
      if (query === "(prefers-reduced-motion: reduce)") {
        return { ...result, matches: true };
      }
      return result;
    });

    await visit("/t/test-topic-no-answer/100");

    assert.dom(".solved-confetti").doesNotExist("confetti is not shown yet");

    await click(".post-action-menu__solved-unaccepted");

    assert
      .dom(".solved-confetti")
      .doesNotExist("confetti is not shown when reduced motion is preferred");
  });
});
