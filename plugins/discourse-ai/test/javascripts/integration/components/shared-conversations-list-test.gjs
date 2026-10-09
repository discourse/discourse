import { click, find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import SharedConversationsList from "discourse/plugins/discourse-ai/discourse/components/shared-conversations-list";

function listData(items, hasMore = false, nextCursor = null) {
  return { items, has_more: hasMore, next_cursor: nextCursor };
}

function share(id, available = true) {
  return {
    id,
    share_key: `key-${id}`,
    title: `Conversation ${id}`,
    url: `/discourse-ai/ai-bot/shared-ai-conversations/key-${id}`,
    created_at: "2026-09-21T12:00:00Z",
    available,
  };
}

function activate(element) {
  element.dispatchEvent(
    new MouseEvent("click", { bubbles: true, cancelable: true })
  );
}

module("Integration | Component | SharedConversationsList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    disableLoadMoreObserver();
  });

  test("renders title, date, available links and revoke-only unavailable rows", async function (assert) {
    this.data = listData([share(1), share(2, false)]);
    await render(
      <template><SharedConversationsList @data={{this.data}} /></template>
    );

    assert
      .dom("#shared-conversations-heading")
      .hasText("Shared AI conversations");
    assert.dom(".shared-conversations__card").exists({ count: 2 });
    assert
      .dom(".shared-conversations__card:first-child h3 a")
      .hasText("Conversation 1");
    assert.dom(".shared-conversations__meta").exists({ count: 2 });
    assert.dom(".shared-conversations__card:last-child h3 a").doesNotExist();
    assert.dom(".shared-conversations__unavailable").exists();
    assert.dom(".shared-conversations__copy-link").exists({ count: 1 });
    assert.dom(".shared-conversations__revoke.btn-danger").exists({ count: 2 });
    assert.dom(".shared-conversations__actions button").exists({ count: 3 });
    assert
      .dom(".shared-conversations iframe")
      .doesNotExist("no preview or embeds");
    assert.dom(".shared-conversations__excerpt").doesNotExist("no excerpts");
    assert
      .dom(".shared-conversations__manage")
      .doesNotExist("no manage action");
  });

  test("copies the absolute link and confirms before revoking", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));
    let deletes = 0;
    pretender.delete(
      "/discourse-ai/ai-bot/shared-ai-conversations/key-1.json",
      () => {
        deletes++;
        return response({});
      }
    );
    this.data = listData([share(1)]);
    await render(
      <template>
        <SharedConversationsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    await click(".shared-conversations__copy-link");
    assert.strictEqual(
      writeText.lastCall.args[0],
      getAbsoluteURL(share(1).url),
      "absolute link is copied"
    );
    await click(".shared-conversations__revoke");
    assert.dom("#dialog-title").hasText("Revoke conversation share?");
    assert.strictEqual(deletes, 0, "opening the confirmation does not delete");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(deletes, 0, "cancellation keeps the share");
    assert.dom(".shared-conversations__card").exists();
    await click(".shared-conversations__revoke");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(deletes, 1, "only confirmation deletes");
    assert
      .dom(".shared-conversations__empty")
      .exists("the revoked row is removed");
  });

  test("sort reloads the feed without a cursor and commits the order only on success", async function (assert) {
    const requests = [];
    pretender.get(
      "/discourse-ai/ai-bot/shared-ai-conversations.json",
      (request) => {
        requests.push(request.queryParams);
        return response(listData([share(2)]));
      }
    );
    this.data = listData([share(1)]);
    await render(
      <template><SharedConversationsList @data={{this.data}} /></template>
    );
    await click(".shared-conversations__sort");
    assert.deepEqual(requests, [{ order: "oldest" }]);
    assert.dom(".shared-conversations__card h3").hasText("Conversation 2");
    assert
      .dom(".shared-conversations__sort")
      .hasText(i18n("discourse_ai.ai_artifact.oldest_first"));
  });

  test("observer pause on confirmation resumes after cancel; failed page retries the same cursor", async function (assert) {
    const cursor = { after: ["2026-09-21", 1] };
    const requests = [];
    pretender.get(
      "/discourse-ai/ai-bot/shared-ai-conversations.json",
      (request) => {
        requests.push(request.queryParams);
        return requests.length === 1
          ? response(500, { errors: ["Unavailable"] })
          : response(listData([share(2)]));
      }
    );
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share(1)], true, cursor);
    await render(
      <template>
        <SharedConversationsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    await click(".shared-conversations__revoke");
    await observations.at(-1).trigger();
    assert.deepEqual(requests, [], "confirmation pauses the observer");
    await click(".dialog-footer .btn-default");
    await observations.at(-1).trigger();
    assert
      .dom(".shared-conversations__retry")
      .exists("failed page shows retry");
    await observations.at(-1).trigger();
    assert.strictEqual(requests.length, 1, "observer cannot auto-retry");
    await click(".shared-conversations__retry");
    assert.deepEqual(
      requests,
      [
        { order: "newest", cursor: JSON.stringify(cursor) },
        { order: "newest", cursor: JSON.stringify(cursor) },
      ],
      "retry retains the opaque cursor"
    );
    assert.dom(".shared-conversations__card").exists({ count: 2 });
  });

  test("in-flight page and deletion guard duplicate requests and preserve the cursor", async function (assert) {
    const cursor = { after: ["2026-09-21", 1] };
    let resolvePage;
    let pageRequests = 0;
    pretender.get("/discourse-ai/ai-bot/shared-ai-conversations.json", () => {
      pageRequests++;
      return new Promise((resolve) => (resolvePage = resolve));
    });
    let resolveDelete;
    let deleteRequests = 0;
    pretender.delete(
      "/discourse-ai/ai-bot/shared-ai-conversations/key-1.json",
      () => {
        deleteRequests++;
        return new Promise((resolve) => (resolveDelete = resolve));
      }
    );
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share(1)], true, cursor);
    await render(
      <template>
        <SharedConversationsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );
    activate(find(".shared-conversations__revoke"));
    activate(find(".shared-conversations__revoke"));
    await settled();
    assert.dom(".dialog-container").exists({ count: 1 });
    activate(find(".dialog-footer .btn-danger"));
    await waitUntil(() => deleteRequests === 1);
    activate(find(".shared-conversations__sort"));
    const pendingScroll = observations.at(-1).trigger();
    await new Promise((resolve) => setTimeout(resolve, 150));
    assert.strictEqual(
      pageRequests,
      0,
      "busy delete prevents pagination and sort"
    );
    resolveDelete(response({}));
    await pendingScroll;
    await settled();
    assert.dom(".shared-conversations__card").doesNotExist();
    const firstLoad = observations.at(-1).trigger();
    await waitUntil(() => pageRequests === 1);
    const secondLoad = observations.at(-1).trigger();
    await new Promise((resolve) => setTimeout(resolve, 150));
    assert.strictEqual(
      pageRequests,
      1,
      "in-flight page is not requested twice"
    );
    assert.dom(".shared-conversations__sort").isDisabled();
    resolvePage(response(listData([share(2)])));
    await Promise.all([firstLoad, secondLoad]);
    assert.dom(".shared-conversations__card h3").hasText("Conversation 2");
  });
});
