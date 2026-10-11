import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";

acceptance("AI artifact - Shared artifacts profile", function (needs) {
  const previewRequests = [];
  let conversationDeletes = 0;
  let artifactRequests = 0;
  let conversationRequests = 0;
  needs.hooks.beforeEach(() => {
    artifactRequests = 0;
    conversationRequests = 0;
  });
  needs.user();
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/artifact-shares.json", () => {
      artifactRequests++;
      return helper.response({
        has_more: false,
        next_cursor: null,
        items: [
          {
            id: "standalone-secret",
            type: "standalone",
            name: "Hello World",
            url: "/discourse-ai/ai-bot/artifact-shares/secret",
            share_key: "secret",
            version: 3,
            available: true,
            created_at: "2026-09-21T12:00:00Z",
          },
          {
            id: "conversation-42",
            type: "conversation",
            name: "Fireworks animation",
            topic_id: 42,
            artifact_id: 321,
            artifact_version: null,
            share_key: "shared",
            url: "/discourse-ai/ai-bot/shared-ai-conversations/shared",
            embed_url: "/artifacts/321/embed",
            available: true,
            created_at: "2026-09-20T12:00:00Z",
          },
        ],
      });
    });
    server.get("/discourse-ai/ai-bot/shared-ai-conversations.json", () => {
      conversationRequests++;
      return helper.response({
        has_more: false,
        next_cursor: null,
        items: [
          {
            id: 42,
            share_key: "shared",
            title: "A shared conversation",
            url: "/discourse-ai/ai-bot/shared-ai-conversations/shared",
            created_at: "2026-09-20T12:00:00Z",
            available: true,
          },
        ],
      });
    });
    server.get(
      "/discourse-ai/ai-bot/shared-ai-conversations/preview/42.json",
      (request) => {
        previewRequests.push(request.url);
        return helper.response({});
      }
    );
    server.delete(
      "/discourse-ai/ai-bot/shared-ai-conversations/shared.json",
      () => {
        conversationDeletes++;
        return helper.response({});
      }
    );
  });

  test("self profile offers actions and confirms conversation revoke", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert
      .dom(".user-nav__activity-shared-artifacts a")
      .hasText("Shared AI artifacts", "artifacts use the canonical name");
    assert
      .dom(".user-nav__activity-shared-conversations a")
      .hasText("Shared AI conversations", "conversations have their own tab");
    await click(".user-nav__activity-shared-artifacts a");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-artifacts",
      "the profile route opens"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "both share types appear together");
    assert.dom(".shared-artifacts__card:first-child h3").hasText("Hello World");
    assert
      .dom(".shared-artifacts__card:last-child h3")
      .hasText("Fireworks animation");
    assert
      .dom(".shared-artifacts iframe")
      .doesNotExist("the profile does not load either artifact document");
    assert
      .dom(".shared-artifacts__card .shared-artifacts__actions button")
      .exists(
        { count: 8 },
        "both cards have copy link, both embeds and revoke"
      );
    assert
      .dom(".shared-artifacts__embed-post")
      .exists({ count: 2 }, "both post actions are direct buttons");
    assert
      .dom(".shared-artifacts__embed-website")
      .exists({ count: 2 }, "both website actions are direct buttons");
    assert
      .dom(".shared-artifacts__card:last-child .shared-artifacts__embed-post")
      .hasText("Embed in post");
    assert
      .dom(
        ".shared-artifacts__card:first-child .shared-artifacts__embed-website"
      )
      .hasText("Embed on website");
    assert
      .dom(".shared-artifacts__revoke.btn-danger")
      .exists({ count: 2 }, "both revoke buttons are red");
    assert
      .dom(".shared-artifacts__card:last-child .shared-artifacts__revoke")
      .hasText("Revoke conversation share");
    assert.deepEqual(previewRequests, [], "listing does not fetch previews");

    await click(".shared-artifacts__card:last-child .shared-artifacts__revoke");
    assert
      .dom("#dialog-title")
      .hasText("Revoke conversation share?", "the dialog identifies its scope");
    assert
      .dom(".dialog-body")
      .hasText(
        "This permanently stops the shared conversation and its artifact embeds. Standalone links are not revoked.",
        "the confirmation explains what is affected"
      );
    assert
      .dom(".dialog-footer .btn-danger")
      .hasText("Revoke conversation share", "the confirm action is dangerous");
    assert.strictEqual(
      conversationDeletes,
      0,
      "no deletion before confirmation"
    );
    assert.dom(".shared-artifacts__card").exists({ count: 2 });

    await click(".dialog-footer .btn-default");
    assert.strictEqual(conversationDeletes, 0, "cancel sends no deletion");
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 2 }, "cancel retains the feed");

    await click(".shared-artifacts__card:last-child .shared-artifacts__revoke");
    assert.strictEqual(
      conversationDeletes,
      0,
      "reopening still does not delete"
    );
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(
      conversationDeletes,
      1,
      "confirmation sends one deletion"
    );
    assert
      .dom(".shared-artifacts__card")
      .exists({ count: 1 }, "confirmed conversation share is removed");
    assert.dom(".shared-artifacts__card h3").hasText("Hello World");
    assert
      .dom(".ai-share-full-topic-modal")
      .doesNotExist("no management modal is opened");
    assert.deepEqual(previewRequests, [], "revoke does not fetch previews");
  });

  test("legacy artifact URL redirects to canonical URL without an extra feed request", async function (assert) {
    await visit("/u/eviltrout/activity/shared-artifacts");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-artifacts",
      "legacy link resolves to canonical route"
    );
    assert.strictEqual(artifactRequests, 1, "only canonical model is fetched");
    assert.strictEqual(
      conversationRequests,
      0,
      "conversation feed is not fetched"
    );
  });

  test("conversations tab loads only the conversation feed", async function (assert) {
    await visit("/u/eviltrout/activity");
    await click(".user-nav__activity-shared-conversations a");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-conversations",
      "canonical conversation route opens"
    );
    assert
      .dom("#shared-conversations-heading")
      .hasText("Shared AI conversations");
    assert
      .dom(".shared-conversations__card h3")
      .hasText("A shared conversation");
    assert.strictEqual(artifactRequests, 0, "artifact feed is not fetched");
    assert.strictEqual(
      conversationRequests,
      1,
      "conversation feed is fetched once"
    );
    assert
      .dom(".shared-conversations iframe")
      .doesNotExist("no artifact embeds");
    assert.dom(".shared-conversations__actions button").exists({ count: 2 });
    assert.dom(".shared-conversations__embed-post").doesNotExist("no embeds");
    assert
      .dom(".shared-conversations__manage")
      .doesNotExist("no manage action");
  });

  test("other profiles do not show or open the private page", async function (assert) {
    await visit("/u/charlie/activity");
    assert
      .dom(".user-nav__activity-shared-artifacts")
      .doesNotExist("private artifact tab is hidden");
    assert
      .dom(".user-nav__activity-shared-conversations")
      .doesNotExist("private conversation tab is hidden");

    await visit("/u/charlie/activity/shared-ai-conversations");
    assert.notStrictEqual(
      currentURL(),
      "/u/charlie/activity/shared-ai-conversations",
      "direct conversation navigation is guarded"
    );
    assert.strictEqual(conversationRequests, 0, "no private feed request");

    await visit("/u/charlie/activity/shared-artifacts");
    assert.notStrictEqual(
      currentURL(),
      "/u/charlie/activity/shared-ai-artifacts",
      "legacy route does not bypass the guard"
    );
    await visit("/u/charlie/activity/shared-ai-artifacts");
    assert.notStrictEqual(
      currentURL(),
      "/u/charlie/activity/shared-ai-artifacts",
      "direct navigation redirects away from the private page"
    );
  });
});

acceptance("AI artifact - Shared artifacts scrolling", function (needs) {
  needs.user();
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      if (request.queryParams.cursor) {
        return helper.response({
          items: [
            {
              id: "conversation-43",
              type: "conversation",
              name: "Later conversation",
              url: "/conversation/43",
              embed_url: "/artifacts/345/1/embed",
              available: true,
              share_key: "share-43",
              topic_id: 43,
              artifact_id: 345,
              artifact_version: 1,
            },
          ],
          has_more: false,
          next_cursor: null,
        });
      }
      return helper.response({
        items: [
          {
            id: "standalone-first",
            type: "standalone",
            name: "First standalone",
            url: "/standalone/first",
            share_key: "first",
            available: true,
          },
        ],
        has_more: true,
        next_cursor: { after: ["2026-09-21", 1] },
      });
    });
  });

  test("scroll observer automatically appends the next mixed page", async function (assert) {
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    try {
      await visit("/u/eviltrout/activity/shared-ai-artifacts");
      assert.dom(".shared-artifacts__card").exists({ count: 1 });
      const sentinel = observations.find(({ element }) =>
        element.closest(".shared-artifacts")
      );
      assert.true(!!sentinel, "the list has a load-more observer");
      await sentinel.trigger();
      assert
        .dom(".shared-artifacts__card")
        .exists({ count: 2 }, "the next page loads without a button");
      assert
        .dom(".shared-artifacts__card:last-child h3")
        .hasText("Later conversation");
      assert
        .dom(".shared-artifacts iframe")
        .doesNotExist("scrolling never mounts artifact documents");
    } finally {
      disableLoadMoreObserver();
    }
  });
});

acceptance("AI artifact - Shared AI artifacts disabled", function (needs) {
  let requests = 0;
  needs.hooks.beforeEach(() => {
    requests = 0;
  });
  needs.user();
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "disabled",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/artifact-shares.json", () => {
      requests++;
      return helper.response({
        items: [
          {
            id: "conversation-42",
            type: "conversation",
            name: "Unavailable conversation",
            share_key: "shared",
            url: "/discourse-ai/ai-bot/shared-ai-conversations/shared",
            available: false,
          },
        ],
        has_more: false,
        next_cursor: null,
      });
    });
    server.get("/discourse-ai/ai-bot/shared-ai-conversations.json", () =>
      helper.response({ items: [], has_more: false, next_cursor: null })
    );
  });

  test("owner can open disabled-security management from the tab and direct or legacy URLs", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert
      .dom(".user-nav__activity-shared-artifacts a")
      .exists("management tab is visible");
    await click(".user-nav__activity-shared-artifacts a");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-artifacts"
    );
    assert
      .dom(".shared-artifacts__card a")
      .doesNotExist("unavailable item has no dead link");
    assert
      .dom(".shared-artifacts__unavailable")
      .exists("unavailable item is explained");
    assert
      .dom(".shared-artifacts__actions button")
      .exists({ count: 1 }, "only revoke remains");
    await visit("/u/eviltrout/activity/shared-artifacts");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-artifacts",
      "legacy URL redirects"
    );
    assert.strictEqual(
      requests,
      2,
      "each visit fetches only the management feed"
    );
  });

  test("disabled security does not expose another user's management routes", async function (assert) {
    await visit("/u/charlie/activity");
    assert
      .dom(".user-nav__activity-shared-artifacts")
      .doesNotExist("other user's tab stays hidden");
    for (const path of ["shared-ai-artifacts", "shared-artifacts"]) {
      await visit(`/u/charlie/activity/${path}`);
      assert.notStrictEqual(
        currentURL(),
        `/u/charlie/activity/shared-ai-artifacts`,
        "private route redirects"
      );
    }
    assert.strictEqual(requests, 0, "no private feed request");
  });
});

acceptance("AI sharing - plugin disabled", function (needs) {
  needs.user();
  needs.settings({ discourse_ai_enabled: false });

  test("neither activity tab nor route is available", async function (assert) {
    await visit("/u/eviltrout/activity");
    assert.dom(".user-nav__activity-shared-artifacts").doesNotExist();
    assert.dom(".user-nav__activity-shared-conversations").doesNotExist();
    await visit("/u/eviltrout/activity/shared-ai-conversations");
    assert.notStrictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-conversations",
      "conversation route is guarded"
    );
  });
});

acceptance("AI sharing - bot disabled", function (needs) {
  needs.user();
  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: false,
    ai_artifact_security: "disabled",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/shared-ai-conversations.json", () =>
      helper.response({ items: [], has_more: false, next_cursor: null })
    );
  });

  test("existing conversations can still be managed", async function (assert) {
    await visit("/u/eviltrout/activity/shared-ai-conversations");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-conversations",
      "management route is not gated by bot sharing eligibility"
    );
    assert.dom(".shared-conversations__empty").exists();
    assert.dom(".user-nav__activity-shared-conversations").exists();
  });
});
