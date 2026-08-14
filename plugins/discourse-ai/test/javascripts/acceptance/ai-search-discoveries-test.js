import { fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Discoveries - user disabled", function (needs) {
  let discoveryRequests;

  needs.user({
    can_use_ai_discover_agent: true,
    user_option: {
      ai_search_discoveries: false,
      ai_search_discoveries_mode: 1,
    },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_discover_enabled: true,
    ai_discover_agent: -34,
  });

  needs.pretender((server, helper) => {
    server.post("/discourse-ai/discoveries/reply", () => {
      discoveryRequests += 1;
      return helper.response({ request_id: "unused" });
    });
  });

  needs.hooks.beforeEach(() => (discoveryRequests = 0));

  test("does not start Discoveries from the welcome search", async function (assert) {
    await visit("/");

    assert
      .dom(".ai-discoveries-mode")
      .doesNotExist("Discoveries controls stay hidden");

    await fillIn("#welcome-banner-search-input", "miyazaki");
    await triggerKeyEvent("#welcome-banner-search-input", "keydown", "Enter");

    assert.strictEqual(
      discoveryRequests,
      0,
      "the disabled user option prevents a Discoveries request"
    );
  });
});
