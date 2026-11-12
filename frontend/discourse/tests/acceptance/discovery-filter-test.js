import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discovery filter", function (needs) {
  let queries;

  needs.hooks.beforeEach(() => {
    queries = [];
  });

  needs.pretender((server, helper) => {
    server.get("/filter.json", (request) => {
      queries.push(request.queryParams.q);
      return helper.response(discoveryFixtures["/latest.json"]);
    });
  });

  test("a labeled filter can be reset to the normal filter view", async function (assert) {
    const queryLabel = 'Questions about <plants> & "gardens"?';
    await visit(
      `/filter?q=topic%3A11557&query_label=${encodeURIComponent(queryLabel)}`
    );

    assert
      .dom(".topic-query-filter__query-text")
      .hasText(
        `Results for: ${queryLabel}`,
        "the original query is displayed as text"
      );
    assert
      .dom(".topic-query-filter__query-text plants")
      .doesNotExist("the query label does not interpret markup");
    assert
      .dom(".topic-query-filter__filter-term")
      .doesNotExist("the raw filter input is hidden");
    assert.strictEqual(
      queries.at(-1),
      "topic:11557",
      "the topic filter is sent to the server"
    );

    assert
      .dom(".topic-query-filter__query .topic-query-filter__reset")
      .hasText("reset", "the reset label is inside the clickable bar");

    await click(".topic-query-filter__query-text");

    assert.strictEqual(
      currentURL(),
      "/filter",
      "reset clears both query parameters"
    );
    assert
      .dom(".topic-query-filter__query")
      .doesNotExist("reset removes the query label");
    assert
      .dom(".topic-query-filter__filter-term")
      .hasValue("", "reset restores an empty filter input");
    assert.strictEqual(
      queries.at(-1),
      "",
      "reset reloads the unfiltered topics"
    );
  });

  test("filters without a query label keep the editable input", async function (assert) {
    await visit("/filter?q=topic%3A11557");

    assert
      .dom(".topic-query-filter__filter-term")
      .hasValue("topic:11557", "ordinary filters remain editable");
    assert
      .dom(".topic-query-filter__query")
      .doesNotExist("ordinary filters have no query label");
  });

  test("a blank query label keeps the editable input", async function (assert) {
    await visit("/filter?q=topic%3A11557&query_label=%20%20");

    assert
      .dom(".topic-query-filter__filter-term")
      .hasValue("topic:11557", "whitespace does not hide the filter");
    assert
      .dom(".topic-query-filter__reset")
      .doesNotExist("there is no query label to reset");
  });
});
