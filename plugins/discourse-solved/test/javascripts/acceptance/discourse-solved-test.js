import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance(`Discourse Solved Plugin`, function (needs) {
  const ITEM_SELECTOR = ".accepted-answers .d-post-accordion-item";
  const BODY_SELECTOR = ".d-post-accordion-item__body";
  const CONTENT_SELECTOR = ".d-post-accordion-item__content";
  const ACCEPTER_SELECTOR = ".accepter-link";

  needs.user();

  test("A topic with an accepted answer shows an excerpt of the answer, if provided", async function (assert) {
    pretender.get("/t/11.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt("this is an excerpt"))
    );

    pretender.get("/t/12.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt(null))
    );

    await visit("/t/with-excerpt/11");

    assert.dom(`${ITEM_SELECTOR} ${CONTENT_SELECTOR}`).exists();
    assert
      .dom(`${ITEM_SELECTOR} ${CONTENT_SELECTOR}`)
      .hasText("this is an excerpt");

    await visit("/t/without-excerpt/12");

    assert
      .dom(`${ITEM_SELECTOR} .d-post-accordion-item--has-content`)
      .doesNotExist();
    assert.dom(`${ITEM_SELECTOR} ${BODY_SELECTOR}`).doesNotExist();
  });

  test("A topic with an accepted answer shows/hides the accepter based on site setting", async function (assert) {
    pretender.get("/t/11.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt("this is an excerpt"))
    );

    await visit("/t/with-excerpt/11");

    assert.dom(`${ITEM_SELECTOR} ${ACCEPTER_SELECTOR}`).doesNotExist();

    this.siteSettings.show_who_marked_solved = true;
    await visit("/t/with-excerpt/11");

    assert.dom(`${ITEM_SELECTOR} ${ACCEPTER_SELECTOR}`).exists();
    assert.dom(`${ITEM_SELECTOR} ${ACCEPTER_SELECTOR}`).hasText("tomtom");
  });

  test("A topic with an accepted answer shows an excerpt of the answer, if provided", async function (assert) {
    pretender.get("/t/11.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt("this is an excerpt"))
    );

    pretender.get("/t/12.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt(null))
    );

    await visit("/t/with-excerpt/11");

    assert.dom(`${ITEM_SELECTOR} ${CONTENT_SELECTOR}`).exists();
    assert
      .dom(`${ITEM_SELECTOR} ${CONTENT_SELECTOR}`)
      .hasText("this is an excerpt");

    await visit("/t/without-excerpt/12");

    assert
      .dom(`${ITEM_SELECTOR} .d-post-accordion-item--has-content`)
      .doesNotExist();
    assert.dom(`${ITEM_SELECTOR} ${BODY_SELECTOR}`).doesNotExist();
  });

  test("A topic with multiple accepted answers shows an excerpt for each", async function (assert) {
    pretender.get("/t/11.json", () => {
      let postStreamWithMultipleAcceptedAnswers =
        postStreamWithAcceptedAnswerExcerpt("this is an excerpt");

      postStreamWithMultipleAcceptedAnswers.accepted_answers.push({
        id: 22,
        name: null,
        username: "kzh",
        avatar_template: "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
        created_at: "2017-08-08T20:12:04.657Z",
        cooked: "<p>another excerpt</p>",
        post_number: 3,
        topic_id: 23,
        url: "/t/with-excerpt/11/3",
        accepter_username: "tomtom",
        accepter_name: "Tomtom",
      });

      return response(postStreamWithMultipleAcceptedAnswers);
    });

    await visit("/t/with-excerpt/11");

    assert.dom(ITEM_SELECTOR).exists({ count: 2 });
    assert
      .dom(`${ITEM_SELECTOR}[data-post='2'] .d-post-accordion-item__content`)
      .hasText("this is an excerpt");
    assert
      .dom(`${ITEM_SELECTOR}[data-post='3'] .d-post-accordion-item__content`)
      .hasText("another excerpt");
  });

  test("Full page search displays solved status", async function (assert) {
    pretender.get("/search", () => {
      const fixtures = cloneJSON(fixturesByUrl["/search.json"]);
      fixtures.topics[0].has_accepted_answer = true;
      return response(fixtures);
    });

    await visit("/search");
    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.dom(".fps-topic").exists({ count: 1 }, "has one post");
    assert.dom(".topic-statuses .--solved").exists("shows the right icon");
  });
});
