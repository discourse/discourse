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
import SharedArtifactsList from "discourse/plugins/discourse-ai/discourse/components/shared-artifacts-list";

function listData(items, { hasMore = false, nextCursor = null } = {}) {
  return { items, has_more: hasMore, next_cursor: nextCursor };
}

function share(name, shareKey, available = true) {
  return {
    id: `standalone-${shareKey}`,
    type: "standalone",
    name,
    url: `/discourse-ai/ai-bot/artifact-shares/${shareKey}`,
    share_key: shareKey,
    version: 0,
    available,
    created_at: "2026-09-21T12:00:00Z",
  };
}

function conversation(name, id, shareKey = `conversation-${id}`) {
  return {
    id: `conversation-${id}`,
    type: "conversation",
    name,
    url: `/discourse-ai/ai-bot/shared-ai-conversations/${shareKey}`,
    embed_url: `/artifacts/${100 + id}/2/embed`,
    available: true,
    share_key: shareKey,
    topic_id: id,
    artifact_id: 100 + id,
    artifact_version: 2,
    created_at: "2026-09-20T12:00:00Z",
  };
}

function deferredRequest(method, path) {
  let resolveRequest;
  let received = 0;
  pretender[method](path, () => {
    received++;
    return new Promise((resolve) => {
      resolveRequest = resolve;
    });
  });

  return {
    get count() {
      return received;
    },
    respond(body) {
      resolveRequest(response(body));
    },
  };
}

// DOM helpers wait for pending requests; dispatch directly to test overlapping actions.
function activate(element) {
  element.dispatchEvent(
    new MouseEvent("click", { bubbles: true, cancelable: true })
  );
}

module("Integration | Component | SharedArtifactsList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    disableLoadMoreObserver();
  });

  test("renders one chronological mixed list with compact cards and no mounted previews", async function (assert) {
    this.data = listData([share("First", "first"), conversation("Second", 42)]);
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    assert
      .dom("#shared-artifacts-heading")
      .hasText("Shared AI artifacts", "page title");
    assert
      .dom(".shared-artifacts")
      .hasAttribute(
        "aria-labelledby",
        "shared-artifacts-heading",
        "title labels the section"
      );
    assert.dom(".shared-artifacts__list").exists({ count: 1 }, "one list");
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "both share types are in the same list");
    assert.dom(".shared-artifacts__card:first-child h3").hasText("First");
    assert.dom(".shared-artifacts__card:last-child h3").hasText("Second");
    assert
      .dom(".shared-artifacts iframe")
      .doesNotExist("neither share type mounts an artifact document");
    assert
      .dom(".shared-artifacts__preview")
      .doesNotExist("there are no preview containers");
    assert
      .dom('.shared-artifacts__filters [aria-pressed="true"]')
      .hasText("All", "all shares selected by default");
    assert
      .dom(
        ".shared-artifacts__card:first-child .shared-artifacts__actions button"
      )
      .exists({ count: 4 }, "standalone has four direct actions");
    assert
      .dom(
        ".shared-artifacts__card:last-child .shared-artifacts__actions button"
      )
      .exists({ count: 4 }, "conversation has the same four direct actions");
    for (const action of ["copy-link", "embed-post", "embed-website"]) {
      assert
        .dom(`.shared-artifacts__${action}`)
        .exists({ count: 2 }, `${action} is explicit on both cards`);
    }
    assert
      .dom(".shared-artifacts__embed-post")
      .hasAttribute(
        "title",
        i18n("discourse_ai.ai_artifact.embed_post_title"),
        "post action explains that it copies code"
      );
    assert
      .dom(".shared-artifacts__embed-website")
      .hasAttribute(
        "title",
        i18n("discourse_ai.ai_artifact.embed_website_title"),
        "website action explains that it copies HTML"
      );
    assert
      .dom(".shared-artifacts__revoke.btn-danger")
      .exists({ count: 2 }, "both revoke actions are red");
    assert
      .dom(".shared-artifacts__card:last-child .shared-artifacts__revoke")
      .hasText(
        i18n("discourse_ai.ai_artifact.revoke_conversation"),
        "conversation revoke identifies its scope"
      );
    assert
      .dom(".shared-artifacts__actions [aria-expanded]")
      .doesNotExist("there are no manage disclosures");
    assert
      .dom(".shared-artifacts__notice")
      .doesNotExist("redundant privacy notice is removed");
    assert
      .dom(".shared-artifacts__footnote")
      .doesNotExist("redundant footnote is removed");
  });

  test("copies explicit post tags and absolute website embeds for both share types", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));
    const external = {
      ...conversation("External", 43),
      url: "https://example.com/conversation",
      embed_url: "https://example.com/artifacts/143/embed",
      artifact_version: null,
    };
    this.data = listData([
      share("Standalone", "first"),
      conversation("Conversation", 42),
      external,
      {
        ...conversation("Original", 44),
        artifact_version: 0,
        embed_url: "/artifacts/144/embed",
      },
    ]);
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    for (let card = 1; card <= 4; card++) {
      for (const action of ["copy-link", "embed-post", "embed-website"]) {
        await click(
          `.shared-artifacts__card:nth-child(${card}) .shared-artifacts__${action}`
        );
      }
    }

    const standaloneURL = getAbsoluteURL(
      "/discourse-ai/ai-bot/artifact-shares/first"
    );
    const conversationURL = getAbsoluteURL(
      "/discourse-ai/ai-bot/shared-ai-conversations/conversation-42"
    );
    const artifactURL = getAbsoluteURL("/artifacts/142/2/embed");
    const embed = (url) =>
      `<iframe src="${url}" width="100%" height="600" frameborder="0"></iframe>`;
    assert.strictEqual(
      writeText.getCall(2).args[0],
      embed(standaloneURL),
      "the copied website iframe keeps the anonymous public share URL, not the native /forum endpoint"
    );
    assert.deepEqual(
      writeText.getCalls().map((call) => call.args[0]),
      [
        standaloneURL,
        '[ai-artifact share="first"]',
        embed(standaloneURL),
        conversationURL,
        '[ai-artifact id="142" version="2"]',
        embed(artifactURL),
        "https://example.com/conversation",
        '[ai-artifact id="143"]',
        embed("https://example.com/artifacts/143/embed"),
        getAbsoluteURL(
          "/discourse-ai/ai-bot/shared-ai-conversations/conversation-44"
        ),
        '[ai-artifact id="144"]',
        embed(getAbsoluteURL("/artifacts/144/embed")),
      ],
      "post tags use share keys or artifact IDs, never URLs; website embeds retain their existing URLs"
    );
  });

  test("unavailable conversations only offer confirmed revoke", async function (assert) {
    let deletes = 0;
    pretender.delete(
      "/discourse-ai/ai-bot/shared-ai-conversations/conversation-42.json",
      () => {
        deletes++;
        return response({});
      }
    );
    this.data = listData([{ ...conversation("Gone", 42), available: false }]);
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} /><DialogHolder />
      </template>
    );
    assert.dom(".shared-artifacts__card h3 a").doesNotExist("no dead link");
    assert.dom(".shared-artifacts__unavailable").exists("shows unavailability");
    assert
      .dom(".shared-artifacts__actions button")
      .exists({ count: 1 }, "revoke only");
    await click(".shared-artifacts__revoke");
    assert
      .dom("#dialog-title")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_title")
      );
    assert.strictEqual(deletes, 0, "confirmation does not delete");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(deletes, 0, "cancel retains share");
    await click(".shared-artifacts__revoke");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(deletes, 1, "confirm deletes once");
  });

  test("keeps unavailable standalone shares revocable without a dead link", async function (assert) {
    let revokedPath;
    pretender.delete(
      "/discourse-ai/ai-bot/artifact-shares/gone.json",
      (request) => {
        revokedPath = request.url;
        return response({});
      }
    );

    this.data = listData([share("Orphan", "gone", false)]);
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    assert.dom(".shared-artifacts__unavailable").exists("unavailable state");
    assert.dom(".shared-artifacts__card a").doesNotExist("no dead link");
    assert
      .dom(".shared-artifacts__actions button")
      .exists({ count: 1 }, "unavailable link can only be revoked");

    await click(".shared-artifacts__revoke");
    assert
      .dom("#dialog-title")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_standalone_title")
      );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_standalone_message")
      );
    assert
      .dom(".dialog-footer .btn-danger")
      .hasText(i18n("discourse_ai.ai_artifact.revoke"));
    assert.strictEqual(
      revokedPath,
      undefined,
      "opening confirmation does not revoke the link"
    );
    await click(".dialog-footer .btn-danger");

    assert.strictEqual(
      revokedPath,
      "/discourse-ai/ai-bot/artifact-shares/gone.json",
      "the owner can revoke the link"
    );
    assert.dom(".shared-artifacts__card").doesNotExist("revoked card removed");
  });

  test("canceling standalone revoke keeps the feed and cursor without a request", async function (assert) {
    let deletes = 0;
    const pages = [];
    const cursor = { after: ["2026-09-21", 4] };
    pretender.delete("/discourse-ai/ai-bot/artifact-shares/first.json", () => {
      deletes++;
      return response({});
    });
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      pages.push(request.queryParams);
      return response(listData([share("Next", "next")]));
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: cursor,
    });
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    await click(".shared-artifacts__revoke");
    assert.strictEqual(deletes, 0, "opening dialog sends no DELETE");
    await observations.at(-1).trigger();
    assert.deepEqual(pages, [], "observer cannot load while confirming");
    await click(".dialog-footer .btn-default");
    assert.dom("#dialog-holder").doesNotExist("cancel closes the dialog");
    assert.strictEqual(deletes, 0, "cancel sends no DELETE");
    assert.deepEqual(pages, [], "cancel sends no list request");
    assert.dom(".shared-artifacts__card h3").hasText("First", "card remains");

    await observations.at(-1).trigger();
    assert.deepEqual(
      pages,
      [{ type: "all", order: "newest", cursor: JSON.stringify(cursor) }],
      "the observer resumes with the original cursor after cancel"
    );
  });

  test("canceling conversation revoke keeps sibling and standalone shares", async function (assert) {
    let deletes = 0;
    pretender.delete(
      "/discourse-ai/ai-bot/shared-ai-conversations/shared.json",
      () => {
        deletes++;
        return response({});
      }
    );
    this.data = listData([
      share("Standalone", "shared"),
      conversation("First", 42, "shared"),
      conversation("Second", 43, "shared"),
    ]);
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    await click(
      ".shared-artifacts__card:nth-child(2) .shared-artifacts__revoke"
    );
    assert.strictEqual(deletes, 0, "opening dialog sends no DELETE");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(deletes, 0, "cancel sends no DELETE");
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 3 }, "all conversation and standalone cards remain");
    assert.dom("#dialog-holder").doesNotExist("cancel closes the dialog");
  });

  test("direct conversation revoke removes sibling cards but not standalone shares", async function (assert) {
    const deletion = deferredRequest(
      "delete",
      "/discourse-ai/ai-bot/shared-ai-conversations/shared.json"
    );
    this.data = listData([
      share("Standalone of the same artifact", "shared"),
      conversation("First conversation artifact", 42, "shared"),
      conversation("Second conversation artifact", 43, "shared"),
      conversation("Another conversation", 44),
    ]);
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );

    const firstRevoke = find(
      ".shared-artifacts__card:nth-child(2) .shared-artifacts__revoke"
    );
    activate(firstRevoke);
    activate(
      find(".shared-artifacts__card:nth-child(3) .shared-artifacts__revoke")
    );
    await settled();
    assert
      .dom("#dialog-title")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_title")
      );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_message")
      );
    assert
      .dom(".dialog-footer .btn-danger")
      .hasText(i18n("discourse_ai.ai_artifact.revoke_conversation"));
    assert.strictEqual(
      deletion.count,
      0,
      "no conversation DELETE before confirm"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 4 }, "all cards stay until confirmation");
    activate(find(".dialog-footer .btn-danger"));
    await waitUntil(() => deletion.count === 1);
    assert.strictEqual(
      deletion.count,
      1,
      "only one conversation DELETE starts"
    );
    assert.true(firstRevoke.disabled, "revoke is disabled while loading");
    assert
      .dom(".shared-artifacts__card:first-child .shared-artifacts__revoke")
      .isDisabled("standalone revoke cannot race the conversation request");

    deletion.respond({});
    await settled();
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "all cards from this conversation are removed");
    assert
      .dom(".shared-artifacts__card:first-child h3")
      .hasText("Standalone of the same artifact", "standalone card remains");
    assert
      .dom(".shared-artifacts__card:last-child h3")
      .hasText("Another conversation", "other conversation remains");
  });

  test("filtering replaces the list and resets the cursor, including after pagination", async function (assert) {
    const requests = [];
    const cursor = { after: ["2026-09-21", 9], seen: [3, 4] };
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests.push(request.queryParams);
      if (request.queryParams.cursor) {
        return response(listData([conversation("Next", 43)]));
      }
      return response(listData([share("Filtered", "filtered")]));
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: cursor,
    });
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    await observations.at(-1).trigger();
    assert.deepEqual(
      requests[0],
      { type: "all", order: "newest", cursor: JSON.stringify(cursor) },
      "the first page uses the initial cursor"
    );
    await click(".shared-artifacts__filters button:nth-child(2)");
    assert.deepEqual(
      requests[1],
      { type: "standalone", order: "newest" },
      "filter change starts at the first page"
    );
    assert
      .dom('.shared-artifacts__filters [aria-pressed="true"]')
      .hasText("Standalone", "filter is selected after success");
    assert.dom(".shared-artifacts__card h3").hasText("Filtered");
  });

  test("sort reloads from the first page using the active filter", async function (assert) {
    const requests = [];
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests.push(request.queryParams);
      return response(listData([conversation("Oldest", 42)]));
    });
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: { key: "old cursor" },
    });
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    await click(".shared-artifacts__filters button:nth-child(3)");
    await click(".shared-artifacts__sort");

    assert.deepEqual(
      requests,
      [
        { type: "conversation", order: "newest" },
        { type: "conversation", order: "oldest" },
      ],
      "filter and sort both reload without passing the old cursor"
    );
    assert
      .dom(".shared-artifacts__sort")
      .hasText(
        i18n("discourse_ai.ai_artifact.oldest_first"),
        "order changes after successful reload"
      );
    assert.dom(".shared-artifacts__card h3").hasText("Oldest");
  });

  test("an in-flight filter reload blocks duplicate filters and sorting", async function (assert) {
    const requests = deferredRequest(
      "get",
      "/discourse-ai/ai-bot/artifact-shares.json"
    );
    this.data = listData([share("First", "first")]);
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    const filter = find(".shared-artifacts__filters button:nth-child(2)");
    activate(filter);
    activate(filter);
    activate(find(".shared-artifacts__sort"));
    await waitUntil(() => requests.count === 1);
    assert.strictEqual(requests.count, 1, "only one reload starts");
    assert.true(filter.disabled, "filters are disabled in flight");
    assert
      .dom(".shared-artifacts__sort")
      .isDisabled("sort is disabled in flight");
    assert
      .dom('.shared-artifacts__filters [aria-pressed="true"]')
      .hasText("All", "the selection changes only on success");
    assert
      .dom(".shared-artifacts__card h3")
      .hasText("First", "cards stay visible");

    requests.respond(listData([share("Filtered", "filtered")]));
    await settled();
    assert.dom(".shared-artifacts__card h3").hasText("Filtered");
    assert
      .dom('.shared-artifacts__filters [aria-pressed="true"]')
      .hasText("Standalone", "selection commits after response");
  });

  test("an in-flight sort reload is not requested twice", async function (assert) {
    const requests = deferredRequest(
      "get",
      "/discourse-ai/ai-bot/artifact-shares.json"
    );
    this.data = listData([share("First", "first")]);
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    const sort = find(".shared-artifacts__sort");
    activate(sort);
    activate(sort);
    await waitUntil(() => requests.count === 1);
    assert.strictEqual(requests.count, 1, "only one sort request starts");
    assert.true(sort.disabled, "sort is disabled while loading");
    assert
      .dom(".shared-artifacts__sort")
      .hasText(
        i18n("discourse_ai.ai_artifact.newest_first"),
        "order does not change before the response"
      );

    requests.respond(listData([share("Oldest", "oldest")]));
    await settled();
    assert.dom(".shared-artifacts__card h3").hasText("Oldest");
    assert
      .dom(".shared-artifacts__sort")
      .hasText(
        i18n("discourse_ai.ai_artifact.oldest_first"),
        "order commits after response"
      );
  });

  test("in-flight requests guard filter, sort, pagination and double revoke", async function (assert) {
    const deletion = deferredRequest(
      "delete",
      "/discourse-ai/ai-bot/artifact-shares/first.json"
    );
    const pages = [];
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      pages.push(request.queryParams);
      return response(listData([]));
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: { key: "keep" },
    });
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );
    const revokeButton = find(".shared-artifacts__revoke");
    activate(revokeButton);
    activate(revokeButton);
    await settled();
    assert
      .dom(".dialog-container")
      .exists({ count: 1 }, "one confirmation opens");
    assert.strictEqual(deletion.count, 0, "duplicate clicks send no DELETE");
    activate(find(".dialog-footer .btn-danger"));
    await waitUntil(() => deletion.count === 1);
    assert.strictEqual(deletion.count, 1, "only one deletion is requested");
    assert.true(revokeButton.disabled, "revoke is disabled in flight");
    assert.dom(".shared-artifacts__sort").isDisabled("sort cannot race revoke");
    assert
      .dom(".shared-artifacts__filters button")
      .isDisabled("filter cannot race revoke");
    activate(find(".shared-artifacts__sort"));
    activate(find(".shared-artifacts__filters button:nth-child(2)"));
    const pendingScroll = observations.at(-1).trigger();
    await new Promise((resolve) => setTimeout(resolve, 150));
    assert.deepEqual(pages, [], "other actions do not start requests");

    deletion.respond({});
    await pendingScroll;
    assert.dom(".shared-artifacts__card").doesNotExist("the item is removed");
    assert.deepEqual(pages, [], "revoke does not reset or reload pagination");
  });

  test("revoke retains the cursor for the next page", async function (assert) {
    const cursor = { timestamp: "2026-09-21", ids: [42, 91] };
    const requests = [];
    pretender.delete("/discourse-ai/ai-bot/artifact-shares/first.json", () =>
      response({})
    );
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests.push(request.queryParams);
      return response(listData([conversation("Unseen", 44)]));
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData(
      [share("First", "first"), conversation("Second", 42)],
      {
        hasMore: true,
        nextCursor: cursor,
      }
    );
    await render(
      <template>
        <SharedArtifactsList @data={{this.data}} />
        <DialogHolder />
      </template>
    );
    await click(
      ".shared-artifacts__card:first-child .shared-artifacts__revoke"
    );
    assert.deepEqual(requests, [], "no pagination request before confirming");
    await click(".dialog-footer .btn-danger");
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 1 }, "revoke removes only the first card");

    await observations.at(-1).trigger();
    assert.deepEqual(
      requests,
      [{ type: "all", order: "newest", cursor: JSON.stringify(cursor) }],
      "pagination keeps the same cursor after deletion"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "the next page is appended");
  });

  test("failed filter and sort requests leave the current feed and selection untouched", async function (assert) {
    let attempts = 0;
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", () => {
      attempts++;
      return response(500, { errors: ["Unavailable"] });
    });
    this.data = listData([share("First", "first")]);
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );
    await click(".shared-artifacts__filters button:nth-child(2)");
    await click(".shared-artifacts__sort");

    assert.strictEqual(attempts, 2, "both reload attempts were made");
    assert.dom(".shared-artifacts__card h3").hasText("First", "list preserved");
    assert
      .dom('.shared-artifacts__filters [aria-pressed="true"]')
      .hasText("All", "filter preserved");
    assert
      .dom(".shared-artifacts__sort")
      .hasText(
        i18n("discourse_ai.ai_artifact.newest_first"),
        "order preserved"
      );
  });

  test("observer loads an empty intermediate page and advances with the opaque cursor", async function (assert) {
    const firstCursor = { after: ["2026-09-21", 4] };
    const secondCursor = { after: ["2026-09-20", 3] };
    const requests = [];
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests.push(request.queryParams);
      return response(
        requests.length === 1
          ? listData([], { hasMore: true, nextCursor: secondCursor })
          : listData([conversation("Later", 43)])
      );
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: firstCursor,
    });
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    await observations.at(-1).trigger();
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 1 }, "empty page does not empty or duplicate the feed");
    await observations.at(-1).trigger();
    assert.deepEqual(
      requests,
      [
        { type: "all", order: "newest", cursor: JSON.stringify(firstCursor) },
        { type: "all", order: "newest", cursor: JSON.stringify(secondCursor) },
      ],
      "each request roundtrips the cursor without interpreting it"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "next page appended");
  });

  test("a pending observer load cannot request the same page twice", async function (assert) {
    const requests = deferredRequest(
      "get",
      "/discourse-ai/ai-bot/artifact-shares.json"
    );
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: { key: "keep" },
    });
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    const firstLoad = observations.at(-1).trigger();
    await waitUntil(() => requests.count === 1);
    const secondLoad = observations.at(-1).trigger();
    await new Promise((resolve) => setTimeout(resolve, 150));
    assert.strictEqual(requests.count, 1, "only one page request is in flight");
    assert
      .dom(".shared-artifacts__filters button")
      .isDisabled("filter cannot race the page request");
    assert
      .dom(".shared-artifacts__sort")
      .isDisabled("sort cannot race the page request");

    requests.respond(listData([conversation("Next", 43)]));
    await Promise.all([firstLoad, secondLoad]);
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "page appended once");
  });

  test("failed observer load pauses until Retry and does not drop the cursor", async function (assert) {
    const cursor = { after: ["2026-09-21", 4] };
    const requests = [];
    pretender.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests.push(request.queryParams);
      return requests.length === 1
        ? response(500, { errors: ["Unavailable"] })
        : response(listData([conversation("Recovered", 43)]));
    });
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    this.data = listData([share("First", "first")], {
      hasMore: true,
      nextCursor: cursor,
    });
    await render(
      <template><SharedArtifactsList @data={{this.data}} /></template>
    );

    await observations.at(-1).trigger();
    assert.dom(".shared-artifacts__retry").exists("retry is shown");
    await observations.at(-1).trigger();
    assert.strictEqual(
      requests.length,
      1,
      "observer cannot retry automatically"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 1 }, "items preserved");

    await click(".shared-artifacts__retry");
    assert.deepEqual(
      requests,
      [
        { type: "all", order: "newest", cursor: JSON.stringify(cursor) },
        { type: "all", order: "newest", cursor: JSON.stringify(cursor) },
      ],
      "retry reuses the same cursor"
    );
    assert.dom(".shared-artifacts__retry").doesNotExist("retry clears");
    assert.dom(".shared-artifacts__card").exists({ count: 2 }, "page appended");
  });
});
