import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { buildRequestId } from "discourse/plugins/discourse-ai/discourse/services/discobot-discoveries";

module("Unit | Service | discobot-discoveries", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    cancel(service.discoveryTimeout);
  });

  test("builds a UUID when randomUUID is unavailable", function (assert) {
    const cryptoProvider = {
      getRandomValues(bytes) {
        bytes.fill(1);
      },
    };

    assert.strictEqual(
      buildRequestId(cryptoProvider),
      "01010101-0101-4101-8101-010101010101"
    );
  });

  test("loads and saves Discoveries result preferences", async function (assert) {
    const savedFields = [];
    const currentUser = {
      user_option: {
        ai_search_discoveries_mode: 0,
        ai_search_discoveries_show_summary: false,
        ai_search_discoveries_summary_detail: 2,
        ai_search_discoveries_related_count: 5,
      },
      save: async (fields) => savedFields.push(fields),
    };
    getOwner(this).unregister("service:current-user");
    getOwner(this).register("service:current-user", currentUser, {
      instantiate: false,
    });
    const service = getOwner(this).lookup("service:discobot-discoveries");

    assert.strictEqual(service.mode, "search");
    assert.false(service.showSummary);
    assert.strictEqual(service.summaryDetail, 2);
    assert.strictEqual(service.relatedCount, 5);

    await service.setRelatedCount(6);

    assert.strictEqual(service.relatedCount, 6);
    assert.deepEqual(savedFields, [["ai_search_discoveries_related_count"]]);
  });

  test("does not send duplicate requests for the same successful query", async function (assert) {
    let requestsCount = 0;
    let submittedRequestId;
    let submittedQuery;

    pretender.post("/discourse-ai/discoveries/reply", (request) => {
      requestsCount += 1;
      const requestBody = new URLSearchParams(request.requestBody);
      submittedRequestId = requestBody.get("request_id");
      submittedQuery = requestBody.get("query");
      return response(200, { request_id: submittedRequestId });
    });

    const service = getOwner(this).lookup("service:discobot-discoveries");

    await service.triggerDiscovery("  What is Discourse?  ");
    await service.triggerDiscovery("What is Discourse?");
    cancel(service.discoveryTimeout);

    assert.strictEqual(requestsCount, 1);
    assert.strictEqual(submittedQuery, "What is Discourse?");
    assert.strictEqual(service.activeRequestId, submittedRequestId);
    assert.true(
      /^[0-9a-f-]{36}$/.test(submittedRequestId),
      "a UUID request ID is submitted"
    );
  });

  test("does not start a request when the user disabled Discoveries", async function (assert) {
    let requestsCount = 0;
    pretender.post("/discourse-ai/discoveries/reply", () => {
      requestsCount += 1;
      return response(200, { request_id: "unused" });
    });
    getOwner(this).unregister("service:current-user");
    getOwner(this).register(
      "service:current-user",
      { user_option: { ai_search_discoveries: false } },
      { instantiate: false }
    );

    const service = getOwner(this).lookup("service:discobot-discoveries");
    await service.triggerDiscovery("miyazaki");

    assert.strictEqual(requestsCount, 0, "no request is made");
    assert.false(service.loadingDiscoveries, "no loading state is shown");
  });

  test("allows retrying the same query when the request fails", async function (assert) {
    let requestsCount = 0;

    pretender.post("/discourse-ai/discoveries/reply", () => {
      requestsCount += 1;
      return response(500, {});
    });

    const service = getOwner(this).lookup("service:discobot-discoveries");

    await service.triggerDiscovery("What is Discourse?");
    await service.triggerDiscovery("What is Discourse?");
    cancel(service.discoveryTimeout);

    assert.strictEqual(requestsCount, 2);
    assert.strictEqual(
      service.errorMessage,
      "Discoveries could not start this search. Try again or use Search."
    );
    assert.false(
      service.discoveryTimedOut,
      "an HTTP failure is not presented as a timeout"
    );
  });

  test("stores source updates without completing the streamed answer", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    const sources = [{ title: "A useful topic", url: "/t/a-useful-topic/123" }];
    service.activeRequestId = "active-request";
    service.loadingDiscoveries = true;

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      sources,
    });

    assert.deepEqual(
      service.sources,
      sources,
      "the source models are retained"
    );
    assert.true(
      service.loadingDiscoveries,
      "the answer remains loading until answer text arrives"
    );

    service.resetDiscovery();

    assert.deepEqual(service.sources, [], "sources reset with the discovery");
  });

  test("stores and resets the structured answer title", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      ai_discover_title: "Two Miyazakis, two bodies of work",
    });

    assert.strictEqual(
      service.discoveryTitle,
      "Two Miyazakis, two bodies of work",
      "the streamed title is retained"
    );

    service.resetDiscovery();

    assert.strictEqual(service.discoveryTitle, "", "the title is reset");
  });

  test("ignores updates from a superseded request", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "current-request";
    service.loadingDiscoveries = true;

    await service.onDiscoveryUpdate({
      request_id: "old-request",
      ai_discover_reply: "An obsolete answer",
      sources: [{ title: "An obsolete source" }],
    });

    assert.strictEqual(service.discovery, "");
    assert.deepEqual(service.sources, []);
    assert.true(service.loadingDiscoveries);
  });

  test("keeps an inactivity timeout until the active request completes", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";
    service.loadingDiscoveries = true;

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      phase: "searching",
      done: false,
    });

    assert.notStrictEqual(
      service.discoveryTimeout,
      null,
      "search progress keeps a timeout armed"
    );

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      phase: "complete",
      ai_discover_reply: "",
      done: true,
    });

    assert.strictEqual(service.discoveryTimeout, null);
    assert.false(service.loadingDiscoveries);
  });

  test("retains a completed no-answer state", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";
    service.loadingDiscoveries = true;

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      phase: "complete",
      answerable: false,
      ai_discover_reply: "",
      done: true,
    });

    assert.false(service.answerable);
    assert.true(service.showDiscoveryTitle);
    assert.false(service.loadingDiscoveries);
  });

  test("a stalled partial answer times out and can be retried", async function (assert) {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";
    service.lastQuery = "What is Discourse?";
    service.discovery = "A partial answer";
    service.sources = [{ title: "A partial source" }];
    service.loadingDiscoveries = false;

    service.timeoutDiscovery();

    assert.true(service.discoveryTimedOut);
    assert.strictEqual(service.discovery, "");
    assert.deepEqual(service.sources, []);
    assert.strictEqual(service.lastQuery, "");
    assert.strictEqual(service.activeRequestId, "");
    assert.false(service.isStreaming);
  });

  test("retains a background processing error", async function (assert) {
    const announcements = [];
    this.owner.register(
      "service:a11y",
      class extends Service {
        announce(message, priority) {
          announcements.push({ message, priority });
        }
      }
    );
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";
    service.lastQuery = "miyazaki";
    service.loadingDiscoveries = true;

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      error: true,
      message: "Discoveries could not complete this search.",
      ai_discover_reply: "",
      done: true,
    });

    assert.strictEqual(
      service.errorMessage,
      "Discoveries could not complete this search."
    );
    assert.true(service.showDiscoveryTitle);
    assert.false(service.loadingDiscoveries);
    assert.strictEqual(
      service.lastQuery,
      "",
      "the failed query can be retried"
    );
    assert.strictEqual(
      service.activeRequestId,
      "",
      "the failed request no longer owns updates"
    );
    assert.deepEqual(
      announcements,
      [
        {
          message: "Discoveries could not complete this search.",
          priority: "assertive",
        },
      ],
      "the error is announced"
    );
  });

  test("announces a completed answer", async function (assert) {
    const announcements = [];
    this.owner.register(
      "service:a11y",
      class extends Service {
        announce(message, priority) {
          announcements.push({ message, priority });
        }
      }
    );
    const service = getOwner(this).lookup("service:discobot-discoveries");
    service.activeRequestId = "active-request";

    await service.onDiscoveryUpdate({
      request_id: "active-request",
      answerable: true,
      ai_discover_reply: "A supported answer.",
      done: true,
    });

    assert.deepEqual(
      announcements,
      [{ message: "Discoveries answer ready.", priority: "polite" }],
      "the completed answer is announced"
    );
  });
});
