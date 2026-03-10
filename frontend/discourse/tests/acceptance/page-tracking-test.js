import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Page tracking - initial load", function (needs) {
  needs.user();
  needs.settings({ beacon_browser_page_view: true });

  needs.hooks.beforeEach(function () {
    this.fetchRequests = [];
    sinon.stub(window, "fetch").callsFake((url, opts) => {
      this.fetchRequests.push({ url, opts });
      return Promise.resolve(new Response("{}", { status: 200 }));
    });
    const meta = document.createElement("meta");
    meta.name = "discourse-track-view-session-id";
    meta.content = "test-session-id";
    document.head.appendChild(meta);
  });

  needs.hooks.afterEach(function () {
    document
      .querySelector("meta[name='discourse-track-view-session-id']")
      ?.remove();
  });

  test("sends pageview on initial load with session_id", async function (assert) {
    await visit("/");
    const pageviewCall = this.fetchRequests.find((r) =>
      r.url.includes("/srv/pv")
    );
    assert.notStrictEqual(pageviewCall, undefined, "fetch called for /srv/pv");
    assert.true(pageviewCall.opts.keepalive);
    const body = JSON.parse(pageviewCall.opts.body);
    assert.strictEqual(body.session_id, "test-session-id");
  });

  test("sends pageview with topic_id on topic route", async function (assert) {
    await visit("/t/some-topic/280");
    const calls = this.fetchRequests.filter((r) => r.url.includes("/srv/pv"));
    const topicCall = calls.find((c) => JSON.parse(c.opts.body).topic_id);
    assert.notStrictEqual(topicCall, undefined, "pageview sent with topic_id");
    assert.strictEqual(JSON.parse(topicCall.opts.body).topic_id, "280");
  });
});
