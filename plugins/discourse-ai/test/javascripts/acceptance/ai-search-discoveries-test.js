import {
  click,
  fillIn,
  find,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("AI Discoveries - search mode", function (needs) {
  needs.user({
    can_use_ai_discover_agent: true,
    user_option: {
      ai_search_discoveries: true,
    },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_discover_enabled: true,
    ai_discover_agent: -34,
    ai_discover_default_mode: "ask",
  });

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", () => helper.response({ user: {} }));
  });

  test("updates the welcome search placeholder with the selected mode", async function (assert) {
    await visit("/");

    assert
      .dom("#welcome-banner-search-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_ai.discobot_discoveries.mode.ask_placeholder")
      )
      .hasAttribute(
        "aria-label",
        i18n("discourse_ai.discobot_discoveries.mode.ask_placeholder")
      );

    await click(".ai-discoveries-mode__option.--search");

    assert
      .dom("#welcome-banner-search-input")
      .hasAttribute("placeholder", i18n("welcome_banner.search_placeholder"))
      .hasAttribute("aria-label", i18n("welcome_banner.search_placeholder"));

    await click(".ai-discoveries-mode__option.--ask");

    assert
      .dom("#welcome-banner-search-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_ai.discobot_discoveries.mode.ask_placeholder")
      )
      .hasAttribute(
        "aria-label",
        i18n("discourse_ai.discobot_discoveries.mode.ask_placeholder")
      );
  });
});

acceptance("AI Discoveries - header search", function (needs) {
  let discoveryRequests;
  let submittedRequestId;

  needs.user({
    can_use_ai_discover_agent: true,
    user_option: {
      ai_search_discoveries: true,
    },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_discover_enabled: true,
    ai_discover_agent: -34,
    ai_discover_default_mode: "ask",
    enable_welcome_banner: false,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));

    server.post("/discourse-ai/discoveries/reply", (request) => {
      discoveryRequests += 1;
      submittedRequestId = helper.parsePostData(request.requestBody).request_id;
      return helper.response({ request_id: submittedRequestId });
    });
  });

  needs.hooks.beforeEach(() => {
    discoveryRequests = 0;
    submittedRequestId = undefined;
  });

  test("replaces indexed results in Ask mode", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert
      .dom(".ai-discoveries-mode")
      .exists("the header search offers Search and Ask modes");

    await fillIn("#icon-search-input", "miyazaki");
    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Enter", bubbles: true })
    );
    await waitFor(".ai-discobot-discoveries");

    assert.strictEqual(
      discoveryRequests,
      1,
      "submitting Ask starts one Discoveries request"
    );
    assert.notStrictEqual(
      submittedRequestId,
      undefined,
      "the request includes an ID"
    );

    assert
      .dom(".ai-discobot-discoveries")
      .exists("the Discoveries result renders in the header search");
    assert
      .dom(".search-result-topic")
      .isNotVisible("indexed results are hidden while Discoveries is running");

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "miyazaki",
      ai_discover_reply: "",
      answerable: false,
      done: true,
    });
  });
});

acceptance("AI Discoveries - user disabled", function (needs) {
  let discoveryRequests;

  needs.user({
    can_use_ai_discover_agent: true,
    user_option: {
      ai_search_discoveries: false,
    },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_discover_enabled: true,
    ai_discover_agent: -34,
    ai_discover_default_mode: "ask",
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
