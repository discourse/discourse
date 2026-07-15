import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Events Calendar - subcategory filter", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    events_calendar_categories: "1",
    calendar_categories: "",
  });

  let lastEventsParams;

  needs.hooks.beforeEach(function () {
    lastEventsParams = undefined;
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events", (request) => {
      lastEventsParams = request.queryParams;
      return helper.response({ events: [] });
    });

    server.get("/c/bug/1/none/l/latest.json", () => {
      return helper.response(
        cloneJSON(fixturesByUrl["/c/bug/1/l/latest.json"])
      );
    });
  });

  test("follows the category list's subcategory filter", async function (assert) {
    await visit("/c/bug/1");

    assert.strictEqual(
      lastEventsParams.include_subcategories,
      "true",
      "requests subcategory events when the list shows subcategory topics"
    );

    lastEventsParams = undefined;
    await visit("/c/bug/1/none");

    assert.strictEqual(
      lastEventsParams?.category_id,
      "1",
      "refetches events when the subcategory filter changes"
    );
    assert.strictEqual(
      lastEventsParams?.include_subcategories,
      undefined,
      "omits subcategory events when the list hides subcategory topics"
    );
  });
});
