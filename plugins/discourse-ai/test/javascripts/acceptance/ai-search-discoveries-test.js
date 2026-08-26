import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("AI Discoveries - welcome search", function (needs) {
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
  });

  test("the placeholder offers both ways to resolve a term", async function (assert) {
    await visit("/");

    assert
      .dom("#welcome-banner-search-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_ai.discobot_discoveries.search_placeholder")
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
    enable_welcome_banner: false,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));

    server.get("/discourse-ai/discoveries/recent", () =>
      helper.response({
        recent_asks: [
          { term: "asked first", at: "2026-08-01T00:00:00Z" },
          { term: "asked last", at: "2026-08-03T00:00:00Z" },
        ],
      })
    );

    server.get("/u/recent-searches", () =>
      helper.response({
        success: "OK",
        recent_searches: ["searched"],
        recent_searches_detailed: [
          { term: "searched", at: "2026-08-02T00:00:00Z" },
        ],
      })
    );

    // mirrors the real endpoint: typing excludes topics, submitting includes them
    server.get("/search/query", (request) => {
      const payload = searchFixtures["search/query"];
      if (request.queryParams.type_filter === DEFAULT_TYPE_FILTER) {
        return helper.response({
          users: payload.users,
          categories: payload.categories,
          groups: payload.groups,
          grouped_search_result: payload.grouped_search_result,
        });
      }
      return helper.response(payload);
    });

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

  test("the placeholder offers both ways to resolve a term", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert
      .dom("#icon-search-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_ai.discobot_discoveries.search_placeholder")
      );
  });

  test("asking is one of the options offered for a typed term", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "miyazaki");

    assert
      .dom(".search-result-user")
      .exists("typing still surfaces indexed suggestions");
    assert
      .dom(".ai-discoveries-search-options__option.--search")
      .exists("the indexed search is offered");
    assert
      .dom(".ai-discoveries-search-options__option.--ask")
      .exists("and asking sits beside it");
    assert
      .dom(".ai-discoveries-search-options__option.--advanced")
      .exists("with advanced search alongside them");
    assert
      .dom(".search-input .show-advanced-search")
      .doesNotExist("and not in the input any more");
    assert
      .dom(".search-menu-initial-options .search-menu-assistant-item")
      .doesNotExist("the native search-all-topics row steps aside for them");
    assert.strictEqual(
      discoveryRequests,
      0,
      "typing alone does not spend a request"
    );

    // dispatched rather than awaited so the discovery timeout does not run
    // during settle
    find(".ai-discoveries-search-options__option.--ask").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    await waitFor(".ai-discobot-discoveries");
    // the panel appears as soon as the query is claimed, before the request lands
    await waitUntil(() => submittedRequestId);

    assert.strictEqual(
      discoveryRequests,
      1,
      "picking it starts one Discoveries request"
    );
    assert
      .dom(".ai-discobot-discoveries")
      .exists("and the answer renders in the search menu");
    assert
      .dom(".search-result-user")
      .doesNotExist("the indexed suggestions step aside for the answer");
    assert
      .dom(".search-icon")
      .doesNotExist("the generic input drops its magnifying glass");

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "miyazaki",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await click(".ai-discoveries-search-options__option.--search");

    assert
      .dom(".ai-discobot-discoveries")
      .doesNotExist("choosing the indexed results puts the answer away");
    assert
      .dom(".search-result-topic")
      .exists("and the indexed results take the space back");
  });

  test("history keeps both kinds, each marked with its own icon", async function (assert) {
    await visit("/");
    await click("#search-button");

    const rows = [
      ...document.querySelectorAll(
        ".search-menu-recent .search-menu-assistant-item"
      ),
    ];

    assert.deepEqual(
      rows.map((row) =>
        row.querySelector(".search-item-slug").textContent.trim()
      ),
      ["asked last", "searched", "asked first"],
      "the two histories interleave by when they happened"
    );
    assert.deepEqual(
      rows.map((row) => !!row.querySelector(".d-icon-far-discobot")),
      [true, false, true],
      "and each row keeps the icon of the kind of search it repeats"
    );
  });

  test("scoping to a topic leaves the input alone", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .exists("the topic scope is offered inline");

    await click(".ai-discoveries-search-options__option.--topic");

    assert
      .dom(".search-menu .search-context")
      .doesNotExist("scoping does not put a chip in the input");
    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .hasClass("is-active", "the inline option carries the scope instead");
    assert
      .dom(".ai-discoveries-search-options__option.--search")
      .exists("and the way back out stays offered");

    await fillIn("#icon-search-input", "dev tooling");

    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .doesNotHaveClass(
        "is-active",
        "a changed term has to be resubmitted, so the scope stops applying"
      );

    await click(".ai-discoveries-search-options__option.--topic");
    await click(".ai-discoveries-search-options__option.--search");

    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .doesNotHaveClass("is-active", "picking all topics releases the scope");
    assert.dom(".search-result-topic").exists("and searches beyond the topic");
  });

  test("still offers itself from a message inbox", async function (assert) {
    await visit("/");
    // the inbox sets this, and it used to disqualify the menu outright
    getOwner(this).lookup("service:search").searchContext = {
      type: "private_messages",
    };

    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    assert
      .dom("#icon-search-input")
      .hasAttribute(
        "placeholder",
        i18n("discourse_ai.discobot_discoveries.search_placeholder"),
        "a scoped context no longer takes the menu out of the plugin's hands"
      );
    assert
      .dom(".ai-discoveries-search-options__option.--ask")
      .exists("so asking stays on offer there");
    assert
      .dom(".search-menu-initial-options .search-menu-assistant-item")
      .doesNotExist(
        "and the native shortcuts still step aside for the options"
      );
  });

  test("enter runs the indexed search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");
    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Enter", bubbles: true })
    );
    await waitFor(".search-result-topic");

    assert
      .dom(".search-result-topic")
      .exists("the indexed results arrive as they always have");
    assert.strictEqual(
      discoveryRequests,
      0,
      "and nothing is asked without picking it"
    );
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
  });

  needs.pretender((server, helper) => {
    server.post("/discourse-ai/discoveries/reply", () => {
      discoveryRequests += 1;
      return helper.response({ request_id: "unused" });
    });
  });

  needs.hooks.beforeEach(() => (discoveryRequests = 0));

  test("does not offer asking from the welcome search", async function (assert) {
    await visit("/");
    await fillIn("#welcome-banner-search-input", "miyazaki");

    assert
      .dom(".ai-discoveries-search-options")
      .doesNotExist("the options stay hidden");
    assert.strictEqual(
      discoveryRequests,
      0,
      "the disabled user option prevents a Discoveries request"
    );
  });
});
