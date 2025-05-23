import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatChannelRow from "discourse/plugins/chat/discourse/components/chat-channel-row";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-row", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.categoryChatChannel = new ChatFabricators(getOwner(this)).channel();
    this.directMessageChannel = new ChatFabricators(
      getOwner(this)
    ).directMessageChannel();
  });

  test("links to correct channel", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel-row")
      .hasAttribute(
        "href",
        `/chat/c/${this.categoryChatChannel.slugifiedTitle}/${this.categoryChatChannel.id}`
      );
  });

  test("allows tabbing", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasAttribute("tabindex", "0");
  });

  test("channel id data attribute", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel-row")
      .hasAttribute(
        "data-chat-channel-id",
        this.categoryChatChannel.id.toString()
      );
  });

  test("renders correct channel title", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel-name__label")
      .hasText(this.categoryChatChannel.title);
  });

  test("renders correct channel metadata", async function (assert) {
    const self = this;

    this.categoryChatChannel.lastMessage = new ChatFabricators(
      getOwner(this)
    ).message({
      created_at: moment().toISOString(),
    });
    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel__metadata-date")
      .hasText(
        moment(this.categoryChatChannel.lastMessage.createdAt).format("h:mm A")
      );
  });

  test("renders membership toggling button when necessary", async function (assert) {
    const self = this;

    forceMobile();

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    this.categoryChatChannel.currentUserMembership.following = true;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    resetMobile();

    await render(
      <template>
        <ChatChannelRow
          @channel={{self.categoryChatChannel}}
          @options={{hash leaveButton=true}}
        />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").exists();
  });

  test("focused channel has correct class", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("focused");

    this.categoryChatChannel.focused = true;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("focused");
  });

  test("muted channel has correct class", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("muted");

    this.categoryChatChannel.currentUserMembership.muted = true;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("muted");
  });

  test("leaveButton options adds correct class", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("can-leave");

    await render(
      <template>
        <ChatChannelRow
          @channel={{self.categoryChatChannel}}
          @options={{hash leaveButton=true}}
        />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("can-leave");
  });

  test("active channel adds correct class", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("active");

    this.owner
      .lookup("service:chat")
      .set("activeChannel", { id: this.categoryChatChannel.id });

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("active");
  });

  test("unreads adds correct class", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("has-unread");

    this.categoryChatChannel.tracking.unreadCount = 1;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("has-unread");
  });

  test("user status with category channel", async function (assert) {
    const self = this;

    await render(
      <template>
        <ChatChannelRow @channel={{self.categoryChatChannel}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("user status with direct message channel", async function (assert) {
    const self = this;

    this.directMessageChannel.chatable = new ChatFabricators(
      getOwner(this)
    ).directMessage({
      users: [new CoreFabricators(getOwner(this)).user()],
    });
    const status = { description: "Off to dentist", emoji: "tooth" };
    this.directMessageChannel.chatable.users[0].status = status;

    await render(
      <template>
        <ChatChannelRow @channel={{self.directMessageChannel}} />
      </template>
    );

    assert.dom(".user-status-message").exists();
  });

  test("user status with direct message channel and multiple users", async function (assert) {
    const self = this;

    const status = { description: "Off to dentist", emoji: "tooth" };
    this.directMessageChannel.chatable.users[0].status = status;

    this.directMessageChannel.chatable.users.push({
      id: 2,
      username: "bill",
      name: null,
      avatar_template: "/letter_avatar_proxy/v3/letter/t/31188e/{size}.png",
    });

    await render(
      <template>
        <ChatChannelRow @channel={{self.directMessageChannel}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });
});
