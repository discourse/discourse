import { click, currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
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
  needs.user({ admin: false, moderator: false });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout.json", () => {
      const profile = userFixtures["/u/eviltrout.json"];
      return helper.response({
        ...profile,
        user: { ...profile.user, admin: false, moderator: false },
      });
    });
    server.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      artifactRequests++;
      return helper.response({
        user_id: Number(request.queryParams.user_id),
        can_manage: true,
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
    server.get(
      "/discourse-ai/ai-bot/shared-ai-conversations.json",
      (request) => {
        conversationRequests++;
        return helper.response({
          user_id: Number(request.queryParams.user_id),
          can_manage: true,
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
      }
    );
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

  test("sidebar offers AI sharing links only on the enabled self profile", async function (assert) {
    this.siteSettings.sidebar_user_navigation = true;

    const artifactsLink =
      '.user-nav-sidebar-link[href="/u/eviltrout/activity/shared-ai-artifacts"]';
    const conversationsLink =
      '.user-nav-sidebar-link[href="/u/eviltrout/activity/shared-ai-conversations"]';

    await visit("/u/eviltrout/activity");
    assert
      .dom(artifactsLink)
      .hasText("Shared AI artifacts", "artifacts appear in the sidebar");
    assert
      .dom(conversationsLink)
      .hasText(
        "Shared AI conversations",
        "conversations appear in the sidebar"
      );

    await click(artifactsLink);
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-artifacts",
      "the sidebar opens artifacts"
    );
    await click(conversationsLink);
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/shared-ai-conversations",
      "the sidebar opens conversations"
    );

    await visit("/u/charlie/activity");
    assert
      .dom('.user-nav-sidebar-link[href*="shared-ai"]')
      .doesNotExist("AI sharing links are private to the current user");

    this.siteSettings.discourse_ai_enabled = false;
    await visit("/u/eviltrout/activity");
    assert
      .dom(artifactsLink)
      .doesNotExist("artifacts are hidden when AI is disabled");
    assert
      .dom(conversationsLink)
      .doesNotExist("conversations are hidden when AI is disabled");
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
  needs.user({ admin: false, moderator: false });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      if (request.queryParams.cursor) {
        return helper.response({
          user_id: Number(request.queryParams.user_id),
          can_manage: true,
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
        user_id: Number(request.queryParams.user_id),
        can_manage: true,
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
  needs.user({ admin: false, moderator: false });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "disabled",
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/artifact-shares.json", (request) => {
      requests++;
      return helper.response({
        user_id: Number(request.queryParams.user_id),
        can_manage: true,
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
  needs.user({ admin: false, moderator: false });
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
  needs.user({ admin: false, moderator: false });
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

acceptance("AI sharing - Administrator inspection", function (needs) {
  const requests = [];
  const state = { failNextPage: false, emptyPages: false, refreshed: false };
  needs.user({ admin: true });
  needs.settings({
    discourse_ai_enabled: true,
    ai_artifact_security: "strict",
  });
  needs.hooks.beforeEach(() => {
    requests.length = 0;
    state.failNextPage = false;
    state.emptyPages = false;
    state.refreshed = false;
  });
  needs.pretender((server, helper) => {
    for (const [username, id] of [
      ["system", -1],
      ["inspectionbot", -100],
      ["zerobot", 0],
    ]) {
      server.get(`/u/${username}.json`, () => {
        const profile = userFixtures["/u/charlie.json"];
        return helper.response({
          ...profile,
          user: { ...profile.user, username, id },
        });
      });
    }

    for (const feed of ["artifact-shares", "shared-ai-conversations"]) {
      server.get(`/discourse-ai/ai-bot/${feed}.json`, (request) => {
        const params = request.queryParams;
        requests.push({ feed, ...params });
        if (params.cursor && state.failNextPage) {
          state.failNextPage = false;
          return helper.response(500, { errors: ["Unavailable"] });
        }
        const inspected = params.user_id === "5";
        const title = state.refreshed
          ? "Fresh publication"
          : inspected
            ? "Published by Charlie"
            : "My own publication";
        if (state.emptyPages) {
          const position = params.cursor ? JSON.parse(params.cursor).id : null;
          const finished = position === 124;
          return helper.response({
            user_id: Number(params.user_id),
            can_manage: false,
            items: finished
              ? [
                  {
                    id: "found",
                    type: "standalone",
                    name: title,
                    title,
                    url: "/published",
                    available: true,
                  },
                ]
              : [],
            has_more: !finished,
            next_cursor: finished
              ? null
              : { id: position === null ? 123 : 124 },
          });
        }
        return helper.response({
          user_id: Number(params.user_id),
          can_manage: !inspected && !state.refreshed,
          items: [
            {
              id: params.cursor ? "second" : "first",
              type: "standalone",
              name: title,
              title,
              url: "/discourse-ai/ai-bot/artifact-shares/published",
              available: true,
              share_key: inspected ? undefined : "own-key",
            },
          ],
          has_more: !params.cursor && !state.refreshed,
          next_cursor:
            params.cursor || state.refreshed
              ? null
              : { id: 123, created_at: "published" },
        });
      });
    }
  });

  test("system and nonpositive bot profiles have no sidebar links, tabs or direct feeds", async function (assert) {
    for (const username of ["system", "inspectionbot", "zerobot"]) {
      this.siteSettings.sidebar_user_navigation = true;
      await visit(`/u/${username}/activity`);
      assert
        .dom('.user-nav-sidebar-link[href*="shared-ai"]')
        .doesNotExist("nonpositive targets have no sidebar inspection links");
      this.siteSettings.sidebar_user_navigation = false;
      await visit(`/u/${username}/activity`);
      assert
        .dom(".user-nav__activity-shared-artifacts")
        .doesNotExist("nonpositive targets have no artifact tab");
      assert
        .dom(".user-nav__activity-shared-conversations")
        .doesNotExist("nonpositive targets have no conversation tab");
      for (const route of [
        "shared-ai-artifacts",
        "shared-ai-conversations",
        "shared-artifacts",
      ]) {
        await visit(`/u/${username}/activity/${route}`);
        assert.strictEqual(
          currentURL(),
          `/u/${username}/activity`,
          "nonpositive targets redirect to their activity page"
        );
      }
    }
    assert.strictEqual(
      requests.length,
      0,
      "invalid profile navigation never requests a feed or falls back to self"
    );
  });

  test("legacy tabs and canonical or legacy routes allow read-only inspection", async function (assert) {
    await visit("/u/charlie/activity");
    assert
      .dom(".user-nav__activity-shared-artifacts a")
      .exists("admin sees the artifact tab");
    assert
      .dom(".user-nav__activity-shared-conversations a")
      .exists("admin sees the conversation tab");
    await click(".user-nav__activity-shared-artifacts a");
    assert
      .dom(".shared-artifacts__card h3")
      .hasText("Published by Charlie", "published artifact is listed");
    assert
      .dom(".shared-artifacts__actions")
      .doesNotExist("inspection has no management or embed controls");
    assert
      .dom(".shared-artifacts iframe")
      .doesNotExist("inspection does not mount a mutable runtime");
    assert.deepEqual(
      requests[0],
      { feed: "artifact-shares", user_id: "5" },
      "initial request targets the inspected user"
    );

    await click(".user-nav__activity-shared-conversations a");
    assert
      .dom(".shared-conversations__card h3")
      .hasText("Published by Charlie", "conversation publication is listed");
    assert
      .dom(".shared-conversations__actions")
      .doesNotExist("conversation inspection has no revoke controls");
    assert.deepEqual(
      requests.at(-1),
      { feed: "shared-ai-conversations", user_id: "5" },
      "conversation request targets the inspected user"
    );

    await visit("/u/charlie/activity/shared-artifacts");
    assert.strictEqual(
      currentURL(),
      "/u/charlie/activity/shared-ai-artifacts",
      "legacy route resolves to the inspected feed"
    );
  });

  test("sidebar supports inspection and changing profile resets the list and owner controls", async function (assert) {
    this.siteSettings.sidebar_user_navigation = true;
    await visit("/u/charlie/activity");
    const artifactLink =
      '.user-nav-sidebar-link[href="/u/charlie/activity/shared-ai-artifacts"]';
    const conversationLink =
      '.user-nav-sidebar-link[href="/u/charlie/activity/shared-ai-conversations"]';
    assert.dom(artifactLink).exists("admin sidebar offers artifacts");
    assert.dom(conversationLink).exists("admin sidebar offers conversations");
    await click(artifactLink);
    assert
      .dom(".shared-artifacts__actions")
      .doesNotExist("inspected artifacts are read-only");

    await visit("/u/eviltrout/activity/shared-ai-artifacts");
    assert
      .dom(".shared-artifacts__card h3")
      .hasText("My own publication", "profile change replaces inspection data");
    assert
      .dom(".shared-artifacts__revoke")
      .exists("admin retains owner management on self");
    await visit("/u/charlie/activity/shared-ai-artifacts");
    assert
      .dom(".shared-artifacts__card h3")
      .hasText(
        "Published by Charlie",
        "changing back recreates inspection data"
      );
    assert
      .dom(".shared-artifacts__actions")
      .doesNotExist("owner controls cannot persist on inspection");

    this.siteSettings.discourse_ai_enabled = false;
    await visit("/u/charlie/activity");
    assert
      .dom(artifactLink)
      .doesNotExist("disabled AI hides administrator artifact navigation");
    assert
      .dom(conversationLink)
      .doesNotExist("disabled AI hides administrator conversation navigation");
    await visit("/u/charlie/activity/shared-ai-artifacts");
    assert.notStrictEqual(
      currentURL(),
      "/u/charlie/activity/shared-ai-artifacts",
      "disabled AI guards direct inspection"
    );
  });

  for (const kind of ["artifacts", "conversations"]) {
    test(`${kind} observer continues through empty inspection pages`, async function (assert) {
      state.emptyPages = true;
      enableLoadMoreObserver();
      const observations = stubIntersectionObserver();
      try {
        await visit(`/u/charlie/activity/shared-ai-${kind}`);
        assert
          .dom(`.shared-${kind}__card`)
          .doesNotExist("an empty first page exposes no unavailable content");
        assert
          .dom(`.shared-${kind}__empty`)
          .doesNotExist(
            "a continuation cursor suppresses the final empty state"
          );
        const firstObserver = observations.at(-1);
        await firstObserver.trigger();
        assert
          .dom(`.shared-${kind}__card`)
          .doesNotExist(
            "an empty intermediate page still exposes no unavailable content"
          );
        assert.notStrictEqual(
          observations.at(-1),
          firstObserver,
          "the observer is rearmed after the empty page"
        );
        await observations.at(-1).trigger();
        assert
          .dom(`.shared-${kind}__card h3`)
          .hasText(
            "Published by Charlie",
            "the next intersection finds the publication"
          );
        assert
          .dom(`.shared-${kind}__actions`)
          .doesNotExist("continued inspection remains read-only");
        assert.deepEqual(
          requests.map(({ user_id, cursor }) => ({ user_id, cursor })),
          [
            { user_id: "5", cursor: undefined },
            { user_id: "5", cursor: JSON.stringify({ id: 123 }) },
            { user_id: "5", cursor: JSON.stringify({ id: 124 }) },
          ],
          "empty pages advance the cursor without losing the target"
        );
      } finally {
        disableLoadMoreObserver();
      }
    });

    test(`${kind} same-user route refresh replaces data, pagination and management authorization`, async function (assert) {
      await visit(`/u/eviltrout/activity/shared-ai-${kind}`);
      assert
        .dom(`.shared-${kind}__card h3`)
        .hasText("My own publication", "the initial owner data is shown");
      assert
        .dom(`.shared-${kind}__revoke`)
        .exists("the initial response permits owner management");
      await click(`.shared-${kind}__sort`);
      await click(`.shared-${kind}__revoke`);
      assert
        .dom(".dialog-container")
        .exists("owner management confirmation is open before refresh");
      state.refreshed = true;
      await this.owner
        .lookup(`route:user-activity.shared-ai-${kind}`)
        .refresh();
      await settled();

      assert
        .dom(`.shared-${kind}__card h3`)
        .hasText(
          "Fresh publication",
          "a refreshed response replaces the same user's old data"
        );
      assert
        .dom(`.shared-${kind}__actions`)
        .doesNotExist(
          "the refreshed management authorization replaces old controls"
        );
      assert
        .dom(".dialog-container")
        .doesNotExist(
          "refresh dismisses the stale owner management confirmation"
        );
      assert
        .dom(`.shared-${kind}__sort`)
        .hasText("Newest first", "refresh resets the prior sort state");
      assert.strictEqual(
        requests.at(-1).user_id,
        "19",
        "refresh still explicitly requests the same target"
      );
    });

    test(`${kind} sort, pagination and retries retain the inspected target`, async function (assert) {
      enableLoadMoreObserver();
      const observations = stubIntersectionObserver();
      try {
        await visit(`/u/charlie/activity/shared-ai-${kind}`);
        if (kind === "artifacts") {
          await click(".shared-artifacts__filters button:nth-child(2)");
        }
        assert.strictEqual(
          requests.at(-1).type,
          kind === "artifacts" ? "standalone" : undefined,
          "only the artifact feed carries its selected filter"
        );
        await click(`.shared-${kind}__sort`);
        assert.strictEqual(
          requests.at(-1).order,
          "oldest",
          "sorting is passed to the target feed"
        );
        state.failNextPage = true;
        await observations.at(-1).trigger();
        assert
          .dom(`.shared-${kind}__retry`)
          .exists("failed target pagination offers retry");
        const failedRequest = requests.at(-1);
        await click(`.shared-${kind}__retry`);
        assert.deepEqual(
          requests.at(-1),
          failedRequest,
          "retry retains the target, order, filter and cursor"
        );
        assert
          .dom(`.shared-${kind}__card`)
          .exists({ count: 2 }, "target page is appended");
        assert.true(
          requests.every((request) => request.user_id === "5"),
          "every request explicitly targets Charlie"
        );
        assert
          .dom(`.shared-${kind}__actions`)
          .doesNotExist("pagination does not introduce management controls");
      } finally {
        disableLoadMoreObserver();
      }
    });
  }
});

for (const viewer of ["moderator", "anonymous"]) {
  acceptance(`AI sharing - ${viewer} access`, function (needs) {
    const state = { requests: 0 };
    if (viewer === "moderator") {
      needs.user({ moderator: true, admin: false });
    }
    needs.settings({
      discourse_ai_enabled: true,
      sidebar_user_navigation: true,
    });
    needs.hooks.beforeEach(() => {
      state.requests = 0;
    });
    needs.pretender((server, helper) => {
      for (const feed of ["artifact-shares", "shared-ai-conversations"]) {
        server.get(`/discourse-ai/ai-bot/${feed}.json`, () => {
          state.requests++;
          return helper.response({ items: [], has_more: false });
        });
      }
    });

    test("another user's sidebar and direct feeds are inaccessible", async function (assert) {
      await visit("/u/charlie/activity");
      assert
        .dom('.user-nav-sidebar-link[href*="shared-ai"]')
        .doesNotExist("inspection links are hidden");
      this.siteSettings.sidebar_user_navigation = false;
      await visit("/u/charlie/activity");
      assert
        .dom(".user-nav__activity-shared-artifacts")
        .doesNotExist("artifact tab is hidden");
      assert
        .dom(".user-nav__activity-shared-conversations")
        .doesNotExist("conversation tab is hidden");
      for (const route of [
        "shared-ai-artifacts",
        "shared-ai-conversations",
        "shared-artifacts",
      ]) {
        await visit(`/u/charlie/activity/${route}`);
        assert.notStrictEqual(
          currentURL(),
          `/u/charlie/activity/${route}`,
          "direct feed navigation redirects away"
        );
      }
      assert.strictEqual(
        state.requests,
        0,
        "guarded navigation makes no feed requests"
      );
    });
  });
}
