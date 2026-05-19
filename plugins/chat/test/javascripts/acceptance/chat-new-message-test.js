import { currentURL, fillIn, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const CHANNEL_ID = 11;
const CHANNEL_SLUG = "my-channel";
const DM_CHANNEL_ID = 75;

function channelPayload({
  id = CHANNEL_ID,
  title = "My channel",
  slug = CHANNEL_SLUG,
  chatableId = 1,
  chatableColor = "ff0000",
  chatableName = "category1",
} = {}) {
  return {
    id,
    title,
    slug,
    chatable_id: chatableId,
    chatable_type: "Category",
    meta: { message_bus_last_ids: {} },
    current_user_membership: { following: true },
    chatable: { id: chatableId, color: chatableColor, name: chatableName },
  };
}

acceptance("Chat | New message", function (needs) {
  let preloadedPublicChannels;

  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });

  needs.hooks.beforeEach(function () {
    preloadedPublicChannels = [channelPayload()];

    pretender.get("/chat/api/me/channels", () =>
      response({
        direct_message_channels: [],
        public_channels: preloadedPublicChannels,
        meta: { message_bus_last_ids: {} },
        tracking: {
          channel_tracking: {
            [CHANNEL_ID]: { unread_count: 0, mention_count: 0 },
          },
          thread_tracking: {},
        },
      })
    );

    pretender.get(`/chat/api/channels/${CHANNEL_ID}/messages`, () =>
      response({ messages: [], meta: {} })
    );

    pretender.post(`/chat/api/channels/${CHANNEL_ID}/drafts`, () =>
      response({})
    );
  });

  test("pre-fills the composer when visiting with channel_id and message", async function (assert) {
    await visit(
      `/chat/new-message?channel_id=${CHANNEL_ID}&message=hello%20world`
    );

    assert.strictEqual(
      currentURL(),
      `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`,
      "redirects to the channel"
    );

    await waitFor(".chat-composer__input", { timeout: 5000 });

    assert
      .dom(".chat-composer__input")
      .hasValue("hello world", "pre-fills the chat composer");
  });

  test("fetches a channel from the server when channel_id is not in the sidebar cache", async function (assert) {
    const UNCACHED_CHANNEL_ID = 42;
    const UNCACHED_CHANNEL_SLUG = "uncached";

    preloadedPublicChannels = [];

    pretender.get(`/chat/api/channels/${UNCACHED_CHANNEL_ID}`, () => {
      assert.step("fetched channel by id");

      return response({
        channel: channelPayload({
          id: UNCACHED_CHANNEL_ID,
          title: "Uncached",
          slug: UNCACHED_CHANNEL_SLUG,
          chatableId: 2,
          chatableColor: "00ff00",
          chatableName: "category2",
        }),
      });
    });

    pretender.get(`/chat/api/channels/${UNCACHED_CHANNEL_ID}/messages`, () =>
      response({ messages: [], meta: {} })
    );

    pretender.post(`/chat/api/channels/${UNCACHED_CHANNEL_ID}/drafts`, () =>
      response({})
    );

    await visit(
      `/chat/new-message?channel_id=${UNCACHED_CHANNEL_ID}&message=id%20link`
    );

    assert.verifySteps(["fetched channel by id"]);
    assert.strictEqual(
      currentURL(),
      `/chat/c/${UNCACHED_CHANNEL_SLUG}/${UNCACHED_CHANNEL_ID}`,
      "redirects to the channel fetched by id"
    );

    await waitFor(".chat-composer__input", { timeout: 5000 });

    assert
      .dom(".chat-composer__input")
      .hasValue("id link", "pre-fills the chat composer");
  });

  test("does not overwrite an existing draft when visiting with channel_id and message", async function (assert) {
    await visit(`/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`);
    await waitFor(".chat-composer__input", { timeout: 5000 });
    await fillIn(".chat-composer__input", "existing draft");

    await visit(
      `/chat/new-message?channel_id=${CHANNEL_ID}&message=replacement%20draft`
    );

    assert.strictEqual(
      currentURL(),
      `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`,
      "redirects back to the channel"
    );

    assert
      .dom(".chat-composer__input")
      .hasValue("existing draft", "keeps the existing composer draft");
  });

  test("pre-fills the composer when visiting with channel slug and message", async function (assert) {
    await visit(
      `/chat/new-message?channel=${CHANNEL_SLUG}&message=hi%20via%20slug`
    );

    assert.strictEqual(
      currentURL(),
      `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`,
      "redirects to the channel"
    );

    await waitFor(".chat-composer__input", { timeout: 5000 });

    assert
      .dom(".chat-composer__input")
      .hasValue("hi via slug", "pre-fills the chat composer");
  });

  test("fetches a channel from the server when its slug is not in the sidebar cache", async function (assert) {
    const UNFOLLOWED_CHANNEL_ID = 42;
    const UNFOLLOWED_CHANNEL_SLUG = "unfollowed";

    pretender.get("/chat/api/channels", () =>
      response({
        channels: [
          {
            id: UNFOLLOWED_CHANNEL_ID,
            title: "Unfollowed",
            slug: UNFOLLOWED_CHANNEL_SLUG,
            chatable_id: 2,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: { following: true },
            chatable: { id: 2, color: "00ff00", name: "category2" },
          },
        ],
        meta: {},
      })
    );

    pretender.get(`/chat/api/channels/${UNFOLLOWED_CHANNEL_ID}/messages`, () =>
      response({ messages: [], meta: {} })
    );

    pretender.post(`/chat/api/channels/${UNFOLLOWED_CHANNEL_ID}/drafts`, () =>
      response({})
    );

    await visit(
      `/chat/new-message?channel=${UNFOLLOWED_CHANNEL_SLUG}&message=external%20link`
    );

    assert.strictEqual(
      currentURL(),
      `/chat/c/${UNFOLLOWED_CHANNEL_SLUG}/${UNFOLLOWED_CHANNEL_ID}`,
      "redirects to the channel resolved from the server"
    );

    await waitFor(".chat-composer__input", { timeout: 5000 });

    assert
      .dom(".chat-composer__input")
      .hasValue("external link", "pre-fills the chat composer");
  });

  function stubDmChannel(onPost) {
    pretender.post("/chat/api/direct-message-channels.json", (request) => {
      onPost?.(request);
      return response({
        channel: {
          id: DM_CHANNEL_ID,
          title: "@hawk",
          slug: "hawk",
          chatable_id: 58,
          chatable_type: "DirectMessage",
          meta: { message_bus_last_ids: {} },
          current_user_membership: { following: true },
          chatable: {
            users: [
              {
                id: 2,
                username: "hawk",
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
              },
            ],
          },
        },
      });
    });

    pretender.get(`/chat/api/channels/${DM_CHANNEL_ID}/messages`, () =>
      response({ messages: [], meta: {} })
    );

    pretender.post(`/chat/api/channels/${DM_CHANNEL_ID}/drafts`, () =>
      response({})
    );
  }

  test("upserts a DM channel and redirects when visiting with recipients", async function (assert) {
    let dmRequestBody;
    stubDmChannel((request) => {
      dmRequestBody = request.requestBody;
    });

    await visit("/chat/new-message?recipients=hawk");

    const decodedBody = decodeURIComponent(dmRequestBody);
    assert.true(
      decodedBody.includes("target_usernames"),
      "posts to direct-message-channels with target_usernames"
    );
    assert.true(decodedBody.includes("hawk"), "posts the recipient username");
    assert.true(decodedBody.includes("upsert=true"), "posts with upsert=true");

    assert.true(
      currentURL().endsWith(`/${DM_CHANNEL_ID}`),
      "redirects to the DM channel"
    );
  });

  test("pre-fills the composer when visiting with recipients and message", async function (assert) {
    stubDmChannel();

    await visit("/chat/new-message?recipients=hawk&message=hello%20from%20DM");

    assert.true(
      currentURL().endsWith(`/${DM_CHANNEL_ID}`),
      "redirects to the DM channel"
    );

    await waitFor(".chat-composer__input", { timeout: 5000 });

    assert
      .dom(".chat-composer__input")
      .hasValue("hello from DM", "pre-fills the chat composer");
  });
});
