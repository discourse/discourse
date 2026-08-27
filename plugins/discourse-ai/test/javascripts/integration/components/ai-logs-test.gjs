import Service from "@ember/service";
import { clearRender, click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiLogs from "discourse/plugins/discourse-ai/discourse/components/ai-logs";
import {
  NEW_LOGS_POLL_BACKOFF_STEP_MS,
  NEW_LOGS_POLL_INTERVAL_MS,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-logs-poll-interval";

const LOG = {
  id: 1,
  created_at: "2026-01-05T10:00:00Z",
  response_status: 200,
  duration_msecs: 1_400,
  feature_name: "summarize",
  model_name: "Test model",
  username: "user1",
  avatar_template: "/letter_avatar_proxy/v4/letter/u/13edae/{size}.png",
  request_tokens: 120,
  response_tokens: 30,
  has_retries: false,
};

class RouterStub extends Service {
  currentRouteName = "adminPlugins.show.discourseAiLogs";

  async transitionTo() {}
  on() {}
  off() {}
}

let pendingNewLogs;
let timerDelays;
let setTimeoutStub;

module("Integration | Component | ai-logs new-log banner", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    setTimeoutStub?.restore();
    setTimeoutStub = undefined;
  });

  hooks.beforeEach(function () {
    pendingNewLogs = 0;

    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);
    this.owner.unregister("service:modal");
    this.owner.register(
      "service:modal",
      class extends Service {
        show() {}
        close() {}
      }
    );
    this.owner.unregister("service:toasts");
    this.owner.register(
      "service:toasts",
      class extends Service {
        success() {}
      }
    );

    pretender.get("/admin/plugins/discourse-ai/ai-logs/new.json", () =>
      response({ new_logs_count: pendingNewLogs })
    );
    pretender.get("/admin/plugins/discourse-ai/ai-logs.json", () =>
      response({ logs: [LOG], meta: { has_more: false } })
    );

    this.set("model", {
      logs: [LOG],
      meta: { has_more: false },
      models: [],
      features: [],
    });
    this.set("queryParams", {});
  });

  test("surfaces new logs in a banner and loads them on click", async function (assert) {
    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    assert.dom(".ai-logs .show-more").doesNotExist("no banner before polling");

    pendingNewLogs = 2;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();

    assert
      .dom(".ai-logs .show-more a.alert-info.clickable")
      .hasText("See 2 new logs", "banner offers to load incoming logs");

    await click(".ai-logs .show-more a");

    assert
      .dom(".ai-logs .show-more")
      .doesNotExist("banner clears once the list reloads");
    assert
      .dom(".ai-logs__row")
      .exists({ count: 1 }, "the reloaded list is rendered");
  });

  test("singularises the count and hides when nothing new remains", async function (assert) {
    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    pendingNewLogs = 1;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();
    assert
      .dom(".ai-logs .show-more a")
      .hasText("See 1 new log", "the count is singularised");

    pendingNewLogs = 0;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();
    assert
      .dom(".ai-logs .show-more")
      .doesNotExist("banner hides once the poll reports nothing new");
  });

  test("backs off after quiet polls and snaps back when logs arrive", async function (assert) {
    const originalSetTimeout = window.setTimeout.bind(window);
    timerDelays = [];
    setTimeoutStub = sinon.stub(window, "setTimeout").callsFake((fn, delay) => {
      timerDelays.push(delay);
      return originalSetTimeout(fn, delay);
    });

    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    timerDelays.length = 0;

    pendingNewLogs = 0;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();
    // quiet poll backs off one step
    assert.strictEqual(
      timerDelays.at(-1),
      NEW_LOGS_POLL_INTERVAL_MS + NEW_LOGS_POLL_BACKOFF_STEP_MS,
      "first quiet poll lengthens the interval"
    );

    pendingNewLogs = 0;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();
    assert.strictEqual(
      timerDelays.at(-1),
      NEW_LOGS_POLL_INTERVAL_MS + 2 * NEW_LOGS_POLL_BACKOFF_STEP_MS,
      "a second quiet poll backs off further"
    );

    pendingNewLogs = 2;
    document.dispatchEvent(new Event("visibilitychange"));
    await settled();
    assert.strictEqual(
      timerDelays.at(-1),
      NEW_LOGS_POLL_INTERVAL_MS,
      "finding new logs snaps the interval back to the base"
    );
  });
  test("keeps the active filters on an ID-prefixed search", async function (assert) {
    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    let pollQuery;
    pretender.get("/admin/plugins/discourse-ai/ai-logs/new.json", (request) => {
      pollQuery = request.queryParams;
      return response({ new_logs_count: 0 });
    });
    this.set("queryParams", {
      period: "hour",
      outcome: "failed",
      search: "topic:424242",
    });

    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    document.dispatchEvent(new Event("visibilitychange"));
    await settled();

    assert.strictEqual(
      pollQuery.search,
      "topic:424242",
      "the prefix is sent as a search term, matching a reload of the same URL"
    );
    assert.strictEqual(
      pollQuery.outcome,
      "failed",
      "the outcome filter survives"
    );
    assert.true("start_date" in pollQuery, "the period filter survives");
    assert.false(
      "topic_id" in pollQuery,
      "no filter-bypassing ID param is sent"
    );
  });

  test("polls against the table high-water mark when the list is empty", async function (assert) {
    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    let pollQuery;
    pretender.get("/admin/plugins/discourse-ai/ai-logs/new.json", (request) => {
      pollQuery = request.queryParams;
      return response({ new_logs_count: 0 });
    });
    this.set("model", {
      logs: [],
      meta: { has_more: false, max_id: 987 },
      models: [],
      features: [],
    });

    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    document.dispatchEvent(new Event("visibilitychange"));
    await settled();

    assert.strictEqual(
      pollQuery.since_id,
      "987",
      "an empty list baselines on the newest existing log, not on zero"
    );
  });

  test("a poll firing after teardown does not schedule another", async function (assert) {
    const originalSetTimeout = window.setTimeout.bind(window);
    const timers = [];
    setTimeoutStub = sinon.stub(window, "setTimeout").callsFake((fn, delay) => {
      timers.push({ fn, delay });
      return originalSetTimeout(fn, delay);
    });

    Object.defineProperty(document, "visibilityState", {
      value: "visible",
      configurable: true,
    });
    await render(
      <template>
        <AiLogs @model={{this.model}} @queryParams={{this.queryParams}} />
      </template>
    );

    const queuedPoll = timers.findLast(
      (timer) => timer.delay === NEW_LOGS_POLL_INTERVAL_MS
    );
    assert.true(Boolean(queuedPoll), "a poll is queued while the page is open");

    await clearRender();
    timers.length = 0;
    queuedPoll.fn();
    await settled();

    assert.deepEqual(
      timers,
      [],
      "the destroyed component leaves no timer behind"
    );
  });
});
