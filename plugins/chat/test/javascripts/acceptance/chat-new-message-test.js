import { getOwner } from "@ember/owner";
import {
  click,
  currentURL,
  fillIn,
  find,
  select,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";

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

  test("full-page Chat fits Main as content above it changes height", async function (assert) {
    this.siteSettings.enable_page_shell_prototype = true;
    this.siteSettings.enable_main_outlet_grid_layout_change = true;

    await visit(`/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`);
    const chatPage = ".page-shell__main .full-page-chat";
    assert.dom(chatPage).exists("renders full-page Chat inside Main");

    const layout = find(chatPage);
    const channel = find(`${chatPage} .chat-channel`);
    await waitUntil(() => layout.style.getPropertyValue("--_chat-page-offset"));

    const chatTop = () => layout.getBoundingClientRect().top + window.scrollY;
    const initialTop = chatTop();
    await click(".page-shell-controls summary");
    assert.true(chatTop() > initialTop, "the expanded controls move Chat down");

    const footer = find(".page-shell__footer");
    for (const placement of ["content", "row", "off"]) {
      await select('.page-shell-controls select[name="footer"]', placement);
      await waitUntil(() => {
        const reserved = parseFloat(
          layout.style.getPropertyValue("--_chat-page-offset")
        );
        return (
          Math.abs(
            reserved - chatTop() - footer.getBoundingClientRect().height
          ) < 1
        );
      });
      assert.true(
        channel.getBoundingClientRect().bottom +
          window.scrollY +
          footer.getBoundingClientRect().height <=
          window.innerHeight + 1,
        `fits the viewport with the footer placement set to ${placement}`
      );
    }

    await visit("/latest");
    assert
      .dom("#main-outlet-wrapper.page-shell")
      .exists("keeps the forum shell on exit");
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

function setupChatContext(needs, { restore = false } = {}) {
  needs.user({ has_chat_enabled: true });
  needs.settings({
    chat_enabled: true,
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
  });

  needs.hooks.beforeEach(function () {
    const userId = loggedInUser().id;
    this.sessionStore = this.owner.lookup("service:session-store");
    this.chatContextURLKey = `chat-context-url:${userId}`;
    this.contextViewKey = `page-shell-context-view:${userId}`;
    if (restore) {
      this.sessionStore.setItem(
        this.chatContextURLKey,
        `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`
      );
      this.sessionStore.setItem(this.contextViewKey, "chat");
    }
  });

  needs.hooks.afterEach(function () {
    this.sessionStore.remove(this.chatContextURLKey);
    this.sessionStore.remove(this.contextViewKey);
  });

  needs.pretender((server, helper) => {
    server.get("/chat/api/me/channels", () =>
      helper.response({
        public_channels: [channelPayload()],
        direct_message_channels: [],
        meta: { message_bus_last_ids: {} },
        tracking: {},
      })
    );
    server.get(`/chat/api/channels/${CHANNEL_ID}/messages`, () =>
      helper.response({ messages: [], meta: {} })
    );
    server.post(`/chat/api/channels/${CHANNEL_ID}/drafts`, () =>
      helper.response({})
    );
  });
}

acceptance("Chat | Page shell Context", function (needs) {
  setupChatContext(needs);

  test("opens Chat in Context and keeps the channel when switching panel views", async function (assert) {
    const owner = getOwner(this);
    const pageShell = owner.lookup("service:page-shell");
    const picker = ".page-shell-context-picker-trigger";
    const chatInContext = "#page-shell-context .chat-drawer";
    const floatingChat = ".chat-drawer-outlet .chat-drawer";

    await visit("/latest");
    await waitUntil(() => pageShell.canOpenContext);
    await click(".chat-header-icon .btn");

    assert.strictEqual(currentURL(), "/latest", "keeps the forum page open");
    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "chat",
        "selects Chat in the header picker"
      );
    assert.dom(chatInContext).isVisible("opens Chat in Context");
    assert.dom(floatingChat).doesNotExist("keeps the floating drawer closed");

    await click(`${chatInContext} a[href*="/chat/c/${CHANNEL_SLUG}/"]`);
    assert
      .dom(chatInContext)
      .hasAttribute(
        "data-chat-channel-id",
        String(CHANNEL_ID),
        "opens the channel in Context"
      );

    await visit("/t/internationalization-localization/280");
    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "chat",
        "keeps Chat selected on a topic"
      );
    assert.dom(chatInContext).isVisible("keeps the channel open");

    await visit("/latest");
    await click(picker);
    await click('[data-context-view-option="about"]');

    assert.dom(chatInContext).doesNotExist("hides Chat in About");
    assert.dom(floatingChat).doesNotExist("leaves the floating drawer closed");

    await click(picker);
    await click('[data-context-view-option="chat"]');

    assert
      .dom(chatInContext)
      .hasAttribute(
        "data-chat-channel-id",
        String(CHANNEL_ID),
        "restores the same channel"
      );

    await click("#toggle-context-panel");

    assert.dom(chatInContext).doesNotExist("closes Chat with Context");
    assert
      .dom(floatingChat)
      .doesNotExist("closing Context keeps the drawer hidden");

    await click("#toggle-context-panel");

    assert
      .dom(chatInContext)
      .hasAttribute(
        "data-chat-channel-id",
        String(CHANNEL_ID),
        "reopening Context restores the channel"
      );

    assert.strictEqual(
      this.sessionStore.getItem(this.chatContextURLKey),
      `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`,
      "remembers the last panel channel in this tab"
    );

    await click(`${chatInContext} .c-navbar__close-drawer-button`);

    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "about",
        "closing Chat shows the default view"
      );
    await click(picker);
    assert
      .dom('[data-context-view-option="chat"] .d-icon-d-chat')
      .exists("keeps Chat and its icon in the picker");
    await click('[data-context-view-option="chat"]');
    assert
      .dom(chatInContext)
      .hasAttribute(
        "data-chat-channel-id",
        String(CHANNEL_ID),
        "reopens the last channel after Chat was closed"
      );

    await click(`${chatInContext} .c-navbar__full-page-button`);

    assert.strictEqual(
      currentURL(),
      `/chat/c/${CHANNEL_SLUG}/${CHANNEL_ID}`,
      "expands to full-page Chat"
    );
    assert.dom(chatInContext).doesNotExist("leaves Context when expanded");
    assert
      .dom(".page-shell__main .full-page-chat")
      .exists("full-page Chat opens in Main");

    assert
      .dom(".c-navbar__open-drawer-button")
      .hasText("Panel view", "offers a way back to Context");
    await click(".c-navbar__open-drawer-button");

    assert.strictEqual(currentURL(), "/latest", "returns to the forum page");
    assert
      .dom(chatInContext)
      .hasAttribute(
        "data-chat-channel-id",
        String(CHANNEL_ID),
        "returns to the same channel in Context"
      );
    assert.dom(floatingChat).doesNotExist("does not open a floating drawer");
  });
});

acceptance("Chat | Page shell Context after reload", function (needs) {
  setupChatContext(needs, { restore: true });

  test("restores the remembered channel when Chat was selected", async function (assert) {
    await visit("/latest");

    const drawer = `#page-shell-context .chat-drawer[data-chat-channel-id="${CHANNEL_ID}"]`;
    await waitFor(drawer);

    assert.dom(drawer).isVisible("shows the last channel in Context");
    assert
      .dom(".chat-drawer-outlet .chat-drawer")
      .doesNotExist("keeps the floating drawer closed");
  });
});
