import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

acceptance("Admin - Webhooks", function (needs) {
  needs.user();

  test("adding a webhook", async function (assert) {
    pretender.get("/admin/api/web_hooks", () => {
      return response({
        web_hooks: [],
        total_rows_web_hooks: 0,
        load_more_web_hooks: "/admin/api/web_hooks.json?limit=50&offset=50",
        extras: {
          content_types: [
            { id: 1, name: "application/json" },
            { id: 2, name: "application/x-www-form-urlencoded" },
          ],
          default_event_types: [{ id: 2, name: "post" }],
          delivery_statuses: [
            { id: 1, name: "inactive" },
            { id: 2, name: "failed" },
            { id: 3, name: "successful" },
          ],
          event_types: [
            { id: 1, name: "topic" },
            { id: 2, name: "post" },
            { id: 3, name: "user" },
            { id: 4, name: "group" },
          ],
        },
      });
    });

    pretender.get("/admin/api/web_hook_events/1", () => {
      return response({
        web_hook_events: [],
        load_more_web_hook_events:
          "/admin/api/web_hook_events/1.json?limit=50&offset=50",
        total_rows_web_hook_events: 15,
        extras: { web_hook_id: 1 },
      });
    });

    pretender.post("/admin/api/web_hooks", (request) => {
      const data = parsePostData(request.requestBody);
      assert.strictEqual(
        data.web_hook.payload_url,
        "https://example.com/webhook"
      );

      return response({
        web_hook: {
          id: 1,
          // other attrs
        },
      });
    });

    await visit("/admin/api/web_hooks");
    await click(".admin-webhooks__new-button");

    await fillIn(`[name="payload-url"`, "https://example.com/webhook");
    await click(".admin-webhooks__save-button");

    assert.strictEqual(currentURL(), "/admin/api/web_hooks/1");
  });
});
