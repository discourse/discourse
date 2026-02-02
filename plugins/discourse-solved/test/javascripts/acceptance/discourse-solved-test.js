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
  needs.user();

  test("A topic with an accepted answer shows an excerpt of the answer, if provided", async function (assert) {
    pretender.get("/t/11.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt("this is an excerpt"))
    );

    pretender.get("/t/12.json", () =>
      response(postStreamWithAcceptedAnswerExcerpt(null))
    );

    await visit("/t/with-excerpt/11");

    assert.dom(".quote.accepted-answer blockquote").exists();
    assert
      .dom(".quote.accepted-answer blockquote")
      .hasText("this is an excerpt");

    await visit("/t/without-excerpt/12");

    assert.dom(".quote.accepted-answer.title-only").exists();
    assert.dom(".quote.accepted-answer blockquote").doesNotExist();
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
