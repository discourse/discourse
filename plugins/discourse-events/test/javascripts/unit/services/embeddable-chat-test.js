import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | embeddable-chat", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    this.topicController = { model: { chat_channel_id: 9 } };
    owner.register("controller:topic", this.topicController, {
      instantiate: false,
    });

    this.router = { currentURL: "/t/a-topic/1" };
    this.capabilities = { viewport: { lg: true } };

    for (const [name, value] of [
      ["router", this.router],
      ["current-user", {}],
      ["capabilities", this.capabilities],
      ["chat", { userCanChat: true }],
      ["chat-state-manager", {}],
    ]) {
      owner.unregister(`service:${name}`);
      owner.register(`service:${name}`, value, { instantiate: false });
    }

    const siteSettings = owner.lookup("service:site-settings");
    siteSettings.chat_enabled = true;
    siteSettings.livestream_embeddable_chat_allowed_paths = "/t";

    this.subject = owner.lookup("service:embeddable-chat");
  });

  test("renders on topic URLs under the allowed path", function (assert) {
    this.router.currentURL = "/t/a-topic/1";
    assert.true(this.subject.canRenderChatChannel(false));

    this.router.currentURL = "/t/a-topic/1/zoom";
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("does not render on unrelated URLs even with a leftover channel", function (assert) {
    this.router.currentURL = "/admin/config/customize/themes";
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("only matches at a path boundary", function (assert) {
    this.router.currentURL = "/tarkov";
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("honors additional configured paths", function (assert) {
    getOwner(this).lookup(
      "service:site-settings"
    ).livestream_embeddable_chat_allowed_paths = "/t|/video";

    this.router.currentURL = "/video/a-livestream/2";
    assert.true(this.subject.canRenderChatChannel(false));

    this.router.currentURL = "/t/a-topic/1";
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("ignores surrounding whitespace in the allowed paths list", function (assert) {
    getOwner(this).lookup(
      "service:site-settings"
    ).livestream_embeddable_chat_allowed_paths = "/t | /video ";

    this.router.currentURL = "/video/a-livestream/2";
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("matches a bare allowed path even with a query string", function (assert) {
    this.router.currentURL = "/t?topic_timer=123";
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("does not render when the topic has no chat channel", function (assert) {
    this.topicController.model = {};
    this.router.currentURL = "/t/a-topic/1";
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("requires the correct viewport", function (assert) {
    this.router.currentURL = "/t/a-topic/1";
    // Desktop viewport expected but mobile requested, and vice versa.
    assert.false(this.subject.canRenderChatChannel(true));

    this.capabilities.viewport.lg = false;
    assert.true(this.subject.canRenderChatChannel(true));
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("shows the header chat icon below the breakpoint with a channel", function (assert) {
    this.capabilities.viewport.lg = false;
    assert.true(this.subject.showLivestreamHeaderChatIcon);

    this.capabilities.viewport.lg = true;
    assert.false(this.subject.showLivestreamHeaderChatIcon);
  });

  test("does not show the header chat icon without a channel", function (assert) {
    this.capabilities.viewport.lg = false;
    this.topicController.model = {};

    assert.false(this.subject.showLivestreamHeaderChatIcon);
  });

  test("hides the header chat icon on a zoom livestream", function (assert) {
    const owner = getOwner(this);
    owner.lookup("service:site-settings").livestream_zoom_enabled = true;
    this.capabilities.viewport.lg = false;

    const event = { is_zoom_livestream: true, ends_at: null };
    this.topicController.model = {
      chat_channel_id: 9,
      // The join button lives on the first post, which is not necessarily the
      // first post loaded into the stream.
      postStream: { posts: [{ post_number: 4 }, { post_number: 1, event }] },
    };

    assert.false(
      this.subject.showLivestreamHeaderChatIcon,
      "the zoom page renders the chat inline instead"
    );

    event.ends_at = moment().subtract(1, "hour").toISOString();
    assert.true(
      this.subject.showLivestreamHeaderChatIcon,
      "the icon comes back once the webinar is over"
    );

    event.ends_at = null;
    owner.lookup("service:site-settings").livestream_zoom_enabled = false;
    assert.true(
      this.subject.showLivestreamHeaderChatIcon,
      "and when the zoom integration is off"
    );
  });
});
