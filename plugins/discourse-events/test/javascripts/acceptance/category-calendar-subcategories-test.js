import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

for (const outlet of [
  "discovery-list-container-top",
  "before-topic-list-body",
]) {
  acceptance(
    `Category Events Calendar - filters (${outlet})`,
    function (needs) {
      needs.user();
      needs.settings({
        discourse_events_enabled: true,
        discourse_post_event_enabled: true,
        events_calendar_categories: "1|2",
        tagging_enabled: true,
        calendar_categories_outlet: outlet,
        calendar_categories: "",
      });

      let lastEventsParams;

      needs.hooks.beforeEach(function () {
        lastEventsParams = undefined;
      });

      needs.pretender((server, helper) => {
        server.get("/tag/12/notifications.json", () =>
          helper.response({
            tag_notification: { id: 12, notification_level: 1 },
          })
        );

        server.get("/discourse-post-event/events", (request) => {
          lastEventsParams = request.queryParams;
          return helper.response({ events: [] });
        });

        [
          "/c/feature/2/l/latest.json",
          "/c/feature/spec/26/l/latest.json",
          "/tags/c/bug/1/planters/12/l/latest.json",
          "/tags/c/bug/1/none/planters/12/l/latest.json",
          "/tags/c/bug/1/none/l/latest.json",
        ].forEach((url) => {
          server.get(url, () =>
            helper.response({
              users: [],
              topic_list: {
                topics: [],
                tags: url.includes("/planters/")
                  ? [{ id: 12, name: "planters", slug: "planters" }]
                  : [],
              },
            })
          );
        });

        server.get("/c/bug/1/none/l/latest.json", () => {
          return helper.response(
            cloneJSON(fixturesByUrl["/c/bug/1/l/latest.json"])
          );
        });
      });

      test("inherits calendar settings when opening a subcategory directly", async function (assert) {
        this.siteSettings.events_calendar_categories = "";
        this.siteSettings.calendar_categories =
          "categoryId=2;defaultView=timeGridWeek;weekends=false";
        await visit("/c/feature/spec/26");
        assert.dom(".fc-timeGridWeek-view").exists();
        assert.dom(".fc-day-sat").doesNotExist();
        assert.strictEqual(lastEventsParams.category_id, "26");
        await visit("/c/bug/1");
        assert.dom(".fc").doesNotExist();
      });

      test("keeps the calendar when selecting and clearing a subcategory", async function (assert) {
        await visit("/c/feature/2");
        assert.dom(".fc").exists();
        await visit("/c/feature/spec/26");
        assert.dom(".fc").exists();
        assert.strictEqual(lastEventsParams.category_id, "26");
        await visit("/c/feature/2");
        assert.dom(".fc").exists();
        assert.strictEqual(lastEventsParams.category_id, "2");
      });

      test("keeps the calendar when selecting and clearing tags", async function (assert) {
        await visit("/c/bug/1");
        await visit("/tags/c/bug/1/planters/12");
        assert.dom(".fc").exists();
        assert.deepEqual(lastEventsParams.tags, ["planters"]);
        assert.strictEqual(lastEventsParams.category_id, "1");
        await visit("/tags/c/bug/1/none/planters/12");
        assert.dom(".fc").exists();
        assert.deepEqual(lastEventsParams.tags, ["planters"]);
        assert.strictEqual(lastEventsParams.include_subcategories, undefined);
        await visit("/tags/c/bug/1/none");
        assert.dom(".fc").exists();
        assert.strictEqual(lastEventsParams.no_tags, "true");
        assert.strictEqual(lastEventsParams.tags, undefined);
        await visit("/c/bug/1");
        assert.dom(".fc").exists();
        assert.strictEqual(lastEventsParams.tags, undefined);
        assert.strictEqual(lastEventsParams.no_tags, undefined);
        assert.strictEqual(lastEventsParams.include_subcategories, "true");
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
    }
  );
}
