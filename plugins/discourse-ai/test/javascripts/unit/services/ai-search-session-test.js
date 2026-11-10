import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { translateResults } from "discourse/lib/search";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function searchResults(ids) {
  return {
    posts: ids.map((id) => ({ id, topic_id: id, blurb: "Battery expansion" })),
    topics: ids.map((id) => ({ id, title: "Battery expansion" })),
    grouped_search_result: {},
  };
}

module("Unit | Service | ai-search-session", function (hooks) {
  setupTest(hooks);

  module("with a deferred answer", function (nestedHooks) {
    let replies;
    let tabReports;

    nestedHooks.beforeEach(function () {
      replies = [];
      tabReports = [];
      this.session = this.owner.lookup("service:ai-search-session");
      this.owner.lookup("service:search").activeGlobalSearchTerm =
        "in:messages";

      pretender.get("/search/query", () => response(searchResults([1])));
      pretender.post("/discourse-ai/discoveries/reply", (request) => {
        const body = new URLSearchParams(request.requestBody);
        replies.push(Object.fromEntries(body));
        return response({
          request_id: body.get("request_id"),
          ask_log_id: 7,
          ...(replies.length === 1 && { answer_deferred: true }),
        });
      });
      pretender.put("/discourse-ai/discoveries/tabs", (request) => {
        tabReports.push(
          Object.fromEntries(new URLSearchParams(request.requestBody))
        );
        return response({});
      });
    });

    nestedHooks.afterEach(function () {
      this.owner
        .lookup("service:discobot-discoveries")
        .cancelDiscoveryTimeout();
    });

    test("opens on results and requests nothing further", async function (assert) {
      this.session.start("in:messages");
      await settled();

      assert.strictEqual(this.session.selectedTab, "topics");
      assert.strictEqual(replies.length, 1, "only the search itself was sent");
      assert.strictEqual(replies[0].defer_if_precise, "true");
      assert.false(
        this.session.discoveries.loadingDiscoveries,
        "nothing is shown as being generated"
      );
    });

    test("requests the answer on the search's log when Ask is opened", async function (assert) {
      this.session.start("in:messages");
      await settled();

      this.session.selectTab("ask");
      assert.true(
        this.session.discoveries.loadingDiscoveries,
        "the answer is now on its way"
      );
      await waitUntil(() => replies.length === 2);

      assert.strictEqual(replies[1].deferred_ask_log_id, "7");
      assert.strictEqual(replies[1].defer_if_precise, undefined);

      this.session.selectTab("topics");
      this.session.selectTab("ask");
      this.session.discoveries.cancelDiscoveryTimeout();
      await settled();
      assert.strictEqual(replies.length, 2, "it is requested only once");
    });

    test("reports when the tab opened and the first result opened", async function (assert) {
      this.session.start("in:messages");
      await settled();

      this.session.recordResultClick("in:messages");
      this.session.recordResultClick("in:messages");
      await settled();

      const opened = tabReports.find((report) => report.tab_opened);
      assert.true(Number(opened.tab_opened_after_ms) >= 0);
      assert.deepEqual(
        tabReports
          .filter((report) => report.result_clicked_tab)
          .map((report) => report.result_clicked_tab),
        ["topics"],
        "only the first click is reported"
      );
    });

    test("ignores a click once the term no longer matches the search", async function (assert) {
      this.session.start("in:messages");
      await settled();

      this.session.recordResultClick("something else");
      await settled();

      assert.false(tabReports.some((report) => report.result_clicked_tab));
    });
  });

  test("reports when an answer is first seen on the Ask tab", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const tabReports = [];
    this.owner.lookup("service:search").activeGlobalSearchTerm = "password";

    pretender.get("/search/query", () => response(searchResults([1])));
    pretender.post("/discourse-ai/discoveries/reply", (request) =>
      response({
        request_id: new URLSearchParams(request.requestBody).get("request_id"),
        ask_log_id: 7,
      })
    );
    pretender.put("/discourse-ai/discoveries/tabs", (request) => {
      tabReports.push(
        Object.fromEntries(new URLSearchParams(request.requestBody))
      );
      return response({});
    });

    const seen = () => tabReports.filter((r) => r.answer_seen_after_ms);

    session.start("password");
    await waitUntil(() => session.selectedTab);
    assert.strictEqual(session.selectedTab, "topics");

    session.onDiscovery({
      query: "password",
      request_id: discoveries.activeRequestId,
      ai_discover_reply: "Reset it from your profile.",
    });
    discoveries.cancelDiscoveryTimeout();
    discoveries.smoothStreamer.resetStreaming();
    await waitUntil(() => tabReports.some((report) => report.tab_opened));
    assert.strictEqual(seen().length, 0, "not while another tab is showing");

    session.selectTab("ask");
    session.selectTab("topics");
    session.selectTab("ask");
    await waitUntil(() => seen().length > 0);
    await settled();
    assert.strictEqual(seen().length, 1, "once the reader is on the answer");
  });

  test("keeps original matches when a larger rewrite result omits one", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([1, 64334]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () => response(searchResults([1, 2, 3])));

    session.onDiscovery({
      query: session.query,
      request_id: discoveries.activeRequestId,
      phase: "rewritten",
      keyword_query: "battery expansion",
    });
    discoveries.cancelDiscoveryTimeout();
    await settled();

    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 64334],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 64334],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 64334],
      "scoped keyword results preserve original matches too"
    );
  });

  test("accepts a rewrite that retains all original matches", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([1, 64334]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () =>
      response(searchResults([1, 2, 64334]))
    );

    session.onDiscovery({
      query: session.query,
      request_id: discoveries.activeRequestId,
      phase: "rewritten",
      keyword_query: "battery expansion",
    });
    discoveries.cancelDiscoveryTimeout();
    await settled();

    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2, 64334],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 2, 64334],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2, 64334],
      "scoped keyword results preserve original matches too"
    );
  });

  test("uses rewritten matches when the original query finds nothing", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () => response(searchResults([1, 2])));

    session.onDiscovery({
      query: session.query,
      request_id: discoveries.activeRequestId,
      phase: "rewritten",
      keyword_query: "battery expansion",
    });
    discoveries.cancelDiscoveryTimeout();
    await settled();

    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 2],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2],
      "scoped keyword results preserve original matches too"
    );
  });

  test("opens on results when a deferred reply lands after the wait but before the results", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const query = "how do I get a refund for my order?";
    this.owner.lookup("service:search").activeGlobalSearchTerm = query;

    // the reply outlasts the wait for it, and the results outlast the reply
    pretender.get("/search/query", () => response(searchResults([1])), 1400);
    pretender.post("/discourse-ai/discoveries/reply", (request) => {
      const reply = response({
        request_id: new URLSearchParams(request.requestBody).get("request_id"),
        ask_log_id: 7,
        answer_deferred: true,
      });
      return new Promise((resolve) => setTimeout(resolve, 1150, reply));
    });
    pretender.put("/discourse-ai/discoveries/tabs", () => response({}));

    session.start(query);
    await waitUntil(() => session.selectedTab, { timeout: 5000 });

    assert.notStrictEqual(
      session.selectedTab,
      "ask",
      "no answer was queued, so the search does not open on one"
    );
  });

  test("asks again for a deferred answer whose request failed", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const replies = [];
    this.owner.lookup("service:search").activeGlobalSearchTerm = "in:messages";

    pretender.get("/search/query", () => response(searchResults([1])));
    pretender.post("/discourse-ai/discoveries/reply", (request) => {
      const body = new URLSearchParams(request.requestBody);
      replies.push(Object.fromEntries(body));
      if (replies.length === 2) {
        return response(429, {});
      }
      return response({
        request_id: body.get("request_id"),
        ask_log_id: 7,
        ...(replies.length === 1 && { answer_deferred: true }),
      });
    });
    pretender.put("/discourse-ai/discoveries/tabs", () => response({}));

    session.start("in:messages");
    await settled();

    session.selectTab("ask");
    await waitUntil(() => discoveries.errorMessage);
    session.selectTab("topics");
    session.selectTab("ask");
    await waitUntil(() => replies.length === 3);
    discoveries.cancelDiscoveryTimeout();

    assert.strictEqual(
      replies[2].deferred_ask_log_id,
      "7",
      "the retry still answers on the search's log"
    );
  });
});
