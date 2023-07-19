import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-row", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.categoryChatChannel = fabricators.channel();
    this.directMessageChannel = fabricators.directMessageChannel();
  });

  test("links to correct channel", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert
      .dom(".chat-channel-row")
      .hasAttribute(
        "href",
        `/chat/c/${this.categoryChatChannel.slugifiedTitle}/${this.categoryChatChannel.id}`
      );
  });

  test("allows tabbing", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").hasAttribute("tabindex", "0");
  });

  test("channel data attrite tabbing", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert
      .dom(".chat-channel-row")
      .hasAttribute(
        "data-chat-channel-id",
        this.categoryChatChannel.id.toString()
      );
  });

  test("renders correct channel title", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-title").hasText(this.categoryChatChannel.title);
  });

  test("renders correct channel metadata", async function (assert) {
    this.categoryChatChannel.lastMessage = fabricators.message({
      created_at: moment().toISOString(),
    });
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert
      .dom(".chat-channel-metadata")
      .hasText(
        moment(this.categoryChatChannel.lastMessage.createdAt).format("h:mm A")
      );
  });

  test("renders membership toggling button when necessary", async function (assert) {
    this.site.desktopView = false;

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}}/>`);

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    this.categoryChatChannel.currentUserMembership.following = true;

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    this.site.desktopView = true;

    await render(
      hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} @options={{hash leaveButton=true}}/>`
    );

    assert.dom(".toggle-channel-membership-button").exists();
  });

  test("focused channel has correct class", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").doesNotHaveClass("focused");

    this.categoryChatChannel.focused = true;

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").hasClass("focused");
  });

  test("muted channel has correct class", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").doesNotHaveClass("muted");

    this.categoryChatChannel.currentUserMembership.muted = true;

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").hasClass("muted");
  });

  test("leaveButton options adds correct class", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").doesNotHaveClass("can-leave");

    await render(
      hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} @options={{hash leaveButton=true}} />`
    );

    assert.dom(".chat-channel-row").hasClass("can-leave");
  });

  test("active channel adds correct class", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").doesNotHaveClass("active");

    this.owner
      .lookup("service:chat")
      .set("activeChannel", { id: this.categoryChatChannel.id });

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").hasClass("active");
  });

  test("unreads adds correct class", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").doesNotHaveClass("has-unread");

    this.categoryChatChannel.tracking.unreadCount = 1;

    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".chat-channel-row").hasClass("has-unread");
  });

  test("user status with category channel", async function (assert) {
    await render(hbs`<ChatChannelRow @channel={{this.categoryChatChannel}} />`);

    assert.dom(".user-status-message").doesNotExist();
  });

  test("user status with direct message channel", async function (assert) {
    this.directMessageChannel.chatable = fabricators.directMessage({
      users: [fabricators.user()],
    });
    const status = { description: "Off to dentist", emoji: "tooth" };
    this.directMessageChannel.chatable.users[0].status = status;

    await render(
      hbs`<ChatChannelRow @channel={{this.directMessageChannel}} />`
    );

    assert.dom(".user-status-message").exists();
  });

  test("user status with direct message channel and multiple users", async function (assert) {
    const status = { description: "Off to dentist", emoji: "tooth" };
    this.directMessageChannel.chatable.users[0].status = status;

    this.directMessageChannel.chatable.users.push({
      id: 2,
      username: "bill",
      name: null,
      avatar_template: "/letter_avatar_proxy/v3/letter/t/31188e/{size}.png",
    });

    await render(
      hbs`<ChatChannelRow @channel={{this.directMessageChannel}} />`
    );

    assert.dom(".user-status-message").doesNotExist();
  });
});
