import { getOwner } from "@ember/owner";
import {
  click,
  currentURL,
  fillIn,
  find,
  settled,
  triggerKeyEvent,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import { removeDefaultQuickSearchRandomTips } from "discourse/components/search-menu/results/random-quick-tip";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  publishToMessageBus,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("AI Discoveries - welcome search", function (needs) {
  let submittedRequestId;

  needs.user({
    can_use_ask_ai: true,
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_ask_ai_enabled: true,
    ai_ask_ai_agent: -41,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));
    server.get("/discourse-ai/discoveries/recent", () =>
      helper.response({ recent_asks: [] })
    );
    server.get("/tags/filter/search", () =>
      helper.response({
        results: [{ id: 87, text: "film", name: "film", slug: "film" }],
      })
    );
    server.post("/discourse-ai/discoveries/reply", (request) => {
      submittedRequestId = helper.parsePostData(request.requestBody).request_id;
      return helper.response({ request_id: submittedRequestId });
    });
  });

  needs.hooks.beforeEach(() => {
    submittedRequestId = undefined;
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

  test("tag suggestions step aside for an Ask AI answer", async function (assert) {
    await visit("/");
    await fillIn(
      "#welcome-banner-search-input",
      "となりのトトロ #general #film"
    );
    await waitFor(".search-menu-assistant .search-menu-assistant-item");

    find(".ai-discoveries-search-options__option.--ask").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);

    assert
      .dom(".search-menu-assistant .search-menu-assistant-item")
      .doesNotExist("the tag suggestion no longer appears below the answer");
  });
});

acceptance("AI Discoveries - header search", function (needs) {
  let discoveryRequests;
  let submittedRequestId;

  needs.user({
    can_use_ask_ai: true,
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_ask_ai_enabled: true,
    ai_ask_ai_agent: -41,
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

    server.delete("/discourse-ai/discoveries/recent", () =>
      helper.response({})
    );
    server.delete("/u/recent-searches", () =>
      helper.response({ success: "OK" })
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

  test("teaches the shortcut that asks", async function (assert) {
    // the menu shows one tip at random, so the assertion is about what is
    // available to show rather than what a given render happened to pick
    removeDefaultQuickSearchRandomTips();

    await visit("/");
    await click("#search-button");

    assert
      .dom(".search-random-quick-tip .tip-label")
      .hasText(
        "Shift + Enter",
        "the keys are named the way the help names them"
      );
    assert
      .dom(".search-random-quick-tip #tip-description")
      .hasText(i18n("discourse_ai.discobot_discoveries.tip_ask"));
  });

  test("marks the search wrapper so it can be styled", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert
      .dom(".search-input-wrapper")
      .hasClass("--with-ask-ai", "the mark is there before anything is typed");
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
      .dom(".ai-discoveries-search-options__option.--ask")
      .doesNotHaveClass(
        "is-active",
        "nothing is marked until an option has produced something"
      );
    assert
      .dom(".ai-discoveries-search-options__option.--advanced")
      .exists("advanced search is offered alongside them");
    assert
      .dom(".search-input .show-advanced-search")
      .doesNotExist("and not in the input any more");
    assert
      .dom(".search-menu-initial-options .search-menu-assistant-item")
      .doesNotExist("the native search-all-topics row steps aside for them");

    await fillIn("#icon-search-input", "miyazaki #code");

    assert
      .dom(".search-menu-initial-options .search-menu-assistant-item")
      .doesNotExist("including the row a modifier in the term would bring");
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
    assert
      .dom(".ai-discoveries-search-options__option.--advanced")
      .exists("advanced search is available for all topics");
  });

  test("keeps a background error visible", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "miyazaki");

    find(".ai-discoveries-search-options__option.--ask").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "miyazaki",
      error: true,
      message: "Ask AI could not complete this search.",
      done: true,
    });

    assert
      .dom(".ai-search-discoveries__error")
      .hasText(
        "Ask AI could not complete this search.",
        "the background error stays mounted in the search menu"
      );
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

  test("clearing the history empties both kinds at once", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert
      .dom(".search-menu-recent .search-menu-assistant-item")
      .exists("asked and searched terms are both listed");

    await click(".clear-recent-searches");

    assert
      .dom(".search-menu-recent")
      .doesNotExist("the whole history goes, without needing a reload");
  });

  test("history from both sources orders by when it happened", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert.deepEqual(
      [...document.querySelectorAll(".search-menu-recent .search-item-slug")]
        .map((item) => item.textContent.trim())
        .filter(Boolean),
      ["asked last", "searched", "asked first"],
      "newest first, whichever list an entry came from"
    );
  });

  test("a recent indexed search repeats as a search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "searched");
    await click(".ai-discoveries-search-options__option.--search");

    find(".ai-discoveries-search-options__option.--ask").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    await waitUntil(() => submittedRequestId);
    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "searched",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await fillIn("#icon-search-input", "");
    await click(
      '.search-menu-recent .search-menu-assistant-item[data-usage="recent-search"]'
    );

    assert
      .dom(".ai-discoveries-search-options__option.--ask")
      .doesNotHaveClass("is-active", "the answer no longer owns the term");
    assert
      .dom(".ai-discobot-discoveries")
      .doesNotExist("the earlier answer is dismissed");
    assert.dom(".search-result-topic").exists("the indexed results replace it");
    assert.strictEqual(
      discoveryRequests,
      1,
      "the history item does not start another Ask AI request"
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

  test("topic scope can be selected with keyboard navigation", async function (assert) {
    updateCurrentUser({ user_option: { ai_ask_ai_default: true } });

    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    await triggerKeyEvent("#icon-search-input", "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .isFocused("arrow navigation focuses the topic scope option");

    await triggerKeyEvent(document.activeElement, "keydown", "Enter");
    assert
      .dom(".ai-discoveries-search-options__option.--topic")
      .hasClass("is-active", "enter scopes the search to the topic");
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

  test("enter searches, shift+enter asks", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Enter", bubbles: true })
    );
    await waitFor(".search-result-topic");

    assert.strictEqual(
      discoveryRequests,
      0,
      "enter runs the indexed search, whatever was picked before"
    );

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", {
        key: "Enter",
        shiftKey: true,
        bubbles: true,
      })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);

    assert.strictEqual(discoveryRequests, 1, "shift+enter asks instead");

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });
  });

  test("the toggle beside an answer saves the preference on the spot", async function (assert) {
    let saved;
    pretender.put("/u/eviltrout.json", (request) => {
      saved = new URLSearchParams(request.requestBody);
      return response({ user: {} });
    });

    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", {
        key: "Enter",
        shiftKey: true,
        bubbles: true,
      })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);
    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await click(".ai-search-discoveries__default-toggle");

    assert.strictEqual(
      saved?.get("ai_ask_ai_default"),
      "true",
      "the choice is sent without waiting for a page to be submitted"
    );
    assert
      .dom(".ai-search-discoveries__default-toggle")
      .hasAria("checked", "true", "and the toggle answers the click");
    assert
      .dom(".ai-discoveries-search-options__option:first-child")
      .hasClass("--ask", "with the row reordered to match");
  });

  test("the preference swaps which key asks", async function (assert) {
    updateCurrentUser({ user_option: { ai_ask_ai_default: true } });

    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Enter", bubbles: true })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);

    assert.strictEqual(
      discoveryRequests,
      1,
      "enter asks once asking is the default"
    );

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await fillIn("#icon-search-input", "themes");
    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", {
        key: "Enter",
        shiftKey: true,
        bubbles: true,
      })
    );
    await waitFor(".search-result-topic");

    assert.strictEqual(
      discoveryRequests,
      1,
      "and shift+enter runs the indexed search instead"
    );
  });

  test("an answer on screen carries through to the full page", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", {
        key: "Enter",
        shiftKey: true,
        bubbles: true,
      })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);
    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await triggerKeyEvent("#icon-search-input", "keydown", "Enter", {
      metaKey: true,
    });

    assert.strictEqual(
      currentURL(),
      "/search?q=dev&search_type=ai_discoveries",
      "the full page opens on the type that produced what was showing"
    );
  });

  test("an indexed search carries through to the full page unchanged", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");
    await click(".ai-discoveries-search-options__option.--search");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Enter", bubbles: true })
    );
    await waitFor(".search-result-topic");

    await click(".ai-discoveries-search-options__option.--advanced");

    assert.strictEqual(
      currentURL(),
      "/search?expanded=true&q=dev",
      "nothing is added when the menu was showing indexed results"
    );
  });

  test("an answer does not come back when its term is typed a second time", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "dev");

    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", {
        key: "Enter",
        shiftKey: true,
        bubbles: true,
      })
    );
    await waitFor(".ai-discobot-discoveries");
    await waitUntil(() => submittedRequestId);
    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    assert.dom(".ai-discobot-discoveries").exists("the answer is showing");

    await fillIn("#icon-search-input", "");
    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "Backspace", bubbles: true })
    );
    await settled();

    await fillIn("#icon-search-input", "dev");
    find("#icon-search-input").dispatchEvent(
      new KeyboardEvent("keyup", { key: "v", bubbles: true })
    );
    await settled();

    assert
      .dom(".ai-discobot-discoveries")
      .doesNotExist("retyping the same term does not bring it back");
    assert
      .dom(".ai-discoveries-search-options__option.--ask")
      .doesNotHaveClass(
        "is-active",
        "and the option that produced it is no longer marked"
      );
    assert.strictEqual(
      discoveryRequests,
      1,
      "and nothing was asked again on its own"
    );
  });
});

acceptance("AI Discoveries - preferences", function (needs) {
  let saved;

  needs.user({
    can_use_ask_ai: true,
    user_option: { ai_ask_ai_default: false },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_ask_ai_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      saved = new URLSearchParams(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  needs.hooks.beforeEach(() => (saved = undefined));

  test("the same setting is offered on the preferences page", async function (assert) {
    await visit("/u/eviltrout/preferences/interface");

    assert
      .dom(".pref-ai-ask-ai-default")
      .exists("the preference is offered alongside the others");

    await click(".pref-ai-ask-ai-default input[type=checkbox]");

    assert.strictEqual(
      saved,
      undefined,
      "nothing is sent until the page is saved"
    );

    await click(".save-changes");

    assert.strictEqual(
      saved?.get("ai_ask_ai_default"),
      "true",
      "and saving the page sends it with the rest"
    );
  });
});

acceptance("AI Discoveries - full page search", function (needs) {
  let discoveryRequests;
  let submittedRequestId;

  needs.user({
    can_use_ask_ai: true,
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_ask_ai_enabled: true,
    ai_ask_ai_agent: -41,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));
    server.get("/discourse-ai/discoveries/recent", () =>
      helper.response({ recent_asks: [] })
    );
    server.get("/search", () =>
      helper.response(searchFixtures["search/query"])
    );
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

  test("switches type with augmented results already on the page", async function (assert) {
    await visit("/search?q=dev");

    // what the semantic-search toggle leaves behind: a ranked list held beside
    // the model, which the stock getter merges with the model's own posts
    const controller = getOwner(this).lookup("controller:full-page-search");
    controller.set("additionalSearchResults", {
      list: [controller.model.posts[0]],
      identifier: "id",
    });
    await settled();

    assert
      .dom(".search-results .fps-result")
      .exists("the augmented results are on the page to begin with");

    await click('.search-types__type[data-search-type="ai_discoveries"]');

    assert
      .dom(".ai-search-discoveries")
      .exists("the switch completes rather than throwing mid-render");
    assert
      .dom(".search-results .fps-result")
      .doesNotExist(
        "and the results it held are not ranked in under the answer"
      );
  });

  test("the preference reorders the types without a reload", async function (assert) {
    await visit("/search?q=dev");

    assert.strictEqual(
      document.querySelector(".search-types__type").dataset.searchType,
      "topics_posts",
      "posts lead while the indexed search is what enter runs"
    );

    updateCurrentUser({ user_option: { ai_ask_ai_default: true } });
    await settled();

    assert.strictEqual(
      document.querySelector(".search-types__type").dataset.searchType,
      "ai_discoveries",
      "and asking leads the moment the preference changes"
    );
  });

  test("asking is a search type of its own", async function (assert) {
    await visit("/search?q=dev");

    assert
      .dom(".full-page-discoveries")
      .doesNotExist("the indexed search is untouched by default");
    assert.deepEqual(
      [...document.querySelectorAll(".search-types__type")].map(
        (pill) => pill.dataset.searchType
      ),
      ["topics_posts", "ai_discoveries", "categories_tags", "users"],
      "asking follows the posts it is an alternative to, rather than trailing the list"
    );

    assert
      .dom(".search-cta")
      .hasText(
        i18n("search.search_button"),
        "the button is labelled for the type in effect"
      );

    await click('.search-types__type[data-search-type="ai_discoveries"]');

    assert
      .dom(".search-cta")
      .hasText(
        i18n("discourse_ai.discobot_discoveries.ask_button"),
        "and asking relabels it, since it submits a question"
      );
    assert
      .dom(".search-cta .d-icon-far-discobot")
      .exists("and the icon follows the label");

    await waitUntil(() => submittedRequestId);

    assert.strictEqual(
      discoveryRequests,
      1,
      "picking the type asks, without a second submission"
    );

    await publishToMessageBus("/discourse-ai/discoveries", {
      request_id: submittedRequestId,
      query: "dev",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });

    await waitFor(".full-page-discoveries");
    await settled();

    assert
      .dom(".full-page-discoveries")
      .exists("and the answer owns the results area");
    assert
      .dom(".search-results .fps-result")
      .doesNotExist("the indexed results step aside for it");
    assert
      .dom(".no-results-container")
      .doesNotExist("and the stock empty state does not contradict the answer");
  });
});

acceptance("Ask AI - deprecated user preference", function (needs) {
  let discoveryRequests;

  needs.user({
    can_use_ask_ai: true,
    user_option: {
      ai_search_discoveries: false,
    },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_ask_ai_enabled: true,
    ai_ask_ai_agent: -41,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));
    server.get("/discourse-ai/discoveries/recent", () =>
      helper.response({ recent_asks: [] })
    );
    server.post("/discourse-ai/discoveries/reply", () => {
      discoveryRequests += 1;
      return helper.response({ request_id: "unused" });
    });
  });

  needs.hooks.beforeEach(() => (discoveryRequests = 0));

  test("does not let the old preference disable Ask AI", async function (assert) {
    await visit("/");
    await fillIn("#welcome-banner-search-input", "miyazaki");

    assert
      .dom(".ai-discoveries-search-options")
      .exists("Ask AI remains available");

    await click(".ai-discoveries-search-options__option.--ask");

    assert.strictEqual(
      discoveryRequests,
      1,
      "the old Discoveries preference does not prevent an Ask AI request"
    );
  });
});

acceptance("Deprecated Discoveries", function (needs) {
  let discoveryRequests;

  needs.user({
    can_use_ai_discover_agent: true,
    can_use_ask_ai: false,
    user_option: { ai_search_discoveries: true },
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_discover_enabled: true,
    ai_discover_agent: -34,
    ai_ask_ai_enabled: false,
    enable_welcome_banner: false,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/credits/status", () => helper.response({}));
    server.get("/search/query", () =>
      helper.response(searchFixtures["search/query"])
    );
    server.post("/discourse-ai/discoveries/reply", () => {
      discoveryRequests += 1;
      return helper.response({});
    });
  });

  needs.hooks.beforeEach(() => (discoveryRequests = 0));

  test("keeps the original Discover search behavior", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#icon-search-input", "miyazaki");

    assert
      .dom(".ai-discoveries-search-options")
      .doesNotExist("Ask AI options are not added to deprecated Discoveries");

    await triggerKeyEvent("#icon-search-input", "keyup", "Enter");
    await waitUntil(() => discoveryRequests === 1);
    await waitFor(".ai-search-discoveries");

    const legacyDiscoveries = getOwner(this).lookup(
      "service:legacy-discobot-discoveries"
    );
    legacyDiscoveries.onDiscoveryUpdate({
      query: "miyazaki",
      model_used: "Test model",
      ai_discover_reply: "Legacy answer",
      done: true,
    });

    assert.strictEqual(legacyDiscoveries.discovery, "Legacy answer");
    assert.strictEqual(legacyDiscoveries.modelUsed, "Test model");
  });
});
