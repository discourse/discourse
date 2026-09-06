import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import CoreFabricators from "discourse/lib/fabricators";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatChannelRow from "discourse/plugins/chat/discourse/components/chat-channel-row";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

function forceTouch(owner) {
  Object.defineProperty(owner.lookup("service:capabilities"), "touch", {
    configurable: true,
    get: () => true,
  });
}

function resetTouch(owner) {
  delete owner.lookup("service:capabilities").touch;
}

async function swipeRowToThreshold(screenX = 10000) {
  const content = find(".chat-channel-row__content");

  for (const [type, x] of [
    ["touchstart", screenX],
    ["touchmove", 0],
    ["touchend", 0],
  ]) {
    const event = new Event(type, { bubbles: true });
    event.changedTouches = [{ screenX: x }];
    event.touches = type === "touchend" ? [] : [{ screenX: x }];
    content.dispatchEvent(event);
  }

  await settled();
}

module("Component | ChatChannelRow", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.categoryChatChannel = new ChatFabricators(getOwner(this)).channel();
    this.directMessageChannel = new ChatFabricators(
      getOwner(this)
    ).directMessageChannel();
  });

  hooks.afterEach(function () {
    resetMobile();
    resetTouch(this.owner);
  });

  test("links to correct channel", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
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
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasAttribute("tabindex", "0");
  });

  test("channel id data attribute", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
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
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel-name__label")
      .hasText(this.categoryChatChannel.title);
  });

  test("renders correct channel metadata", async function (assert) {
    this.categoryChatChannel.lastMessage = new ChatFabricators(
      getOwner(this)
    ).message({
      created_at: moment().toISOString(),
    });
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert
      .dom(".chat-channel__metadata-date")
      .hasText(
        moment(this.categoryChatChannel.lastMessage.createdAt).format("h:mm A")
      );
  });

  test("renders membership toggling button when necessary", async function (assert) {
    forceMobile();

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    this.categoryChatChannel.currentUserMembership.following = true;

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").doesNotExist();

    resetMobile();

    await render(
      <template>
        <ChatChannelRow
          @channel={{this.categoryChatChannel}}
          @options={{hash leaveButton=true}}
        />
      </template>
    );

    assert.dom(".toggle-channel-membership-button").exists();
  });

  test("focused channel has correct class", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("focused");

    this.categoryChatChannel.focused = true;

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("focused");
  });

  test("muted channel has correct class", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("muted");

    this.categoryChatChannel.currentUserMembership.muted = true;

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("muted");
  });

  test("leaveButton options adds correct class", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("can-leave");

    await render(
      <template>
        <ChatChannelRow
          @channel={{this.categoryChatChannel}}
          @options={{hash leaveButton=true}}
        />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("can-leave");
  });

  test("active channel adds correct class", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("active");

    this.owner
      .lookup("service:chat")
      .set("activeChannel", { id: this.categoryChatChannel.id });

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("active");
  });

  test("unreads adds correct class", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").doesNotHaveClass("has-unread");

    this.categoryChatChannel.tracking.unreadCount = 1;

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".chat-channel-row").hasClass("has-unread");
  });

  test("user status with category channel", async function (assert) {
    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("user status with direct message channel", async function (assert) {
    this.directMessageChannel.chatable = new ChatFabricators(
      getOwner(this)
    ).directMessage({
      users: [new CoreFabricators(getOwner(this)).user()],
    });
    const status = { description: "Off to dentist", emoji: "tooth" };
    this.directMessageChannel.chatable.users[0].status = status;

    await render(
      <template>
        <ChatChannelRow @channel={{this.directMessageChannel}} />
      </template>
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
      <template>
        <ChatChannelRow @channel={{this.directMessageChannel}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("swiping a channel with notifications clears them", async function (assert) {
    forceMobile();
    forceTouch(this.owner);
    const markAsRead = sinon
      .stub(this.owner.lookup("service:chat-api"), "markChannelAsRead")
      .resolves();
    this.categoryChatChannel.tracking.unreadCount = 1;

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    await swipeRowToThreshold();

    assert.dom(".chat-channel-row__action-btn.--clear").exists();
    assert.dom(".chat-channel-row__action-btn .d-icon-circle-check").exists();
    assert.dom(".chat-channel-row").doesNotHaveClass("-fade-out");
    assert.true(
      markAsRead.calledWith(
        this.categoryChatChannel.id,
        this.categoryChatChannel.lastMessage.id
      ),
      "marks the channel as read up to the last message"
    );
    assert.strictEqual(this.categoryChatChannel.tracking.unreadCount, 0);
  });

  test("channels without notifications are not swipeable", async function (assert) {
    forceMobile();
    forceTouch(this.owner);

    await render(
      <template>
        <ChatChannelRow @channel={{this.categoryChatChannel}} />
      </template>
    );

    await swipeRowToThreshold();

    assert.dom(".chat-channel-row__action-btn").doesNotExist();
  });

  test("swiping a direct message reveals the remove action", async function (assert) {
    forceMobile();
    forceTouch(this.owner);
    const markAsRead = sinon.spy(
      this.owner.lookup("service:chat-api"),
      "markChannelAsRead"
    );

    await render(
      <template>
        <ChatChannelRow @channel={{this.directMessageChannel}} />
      </template>
    );

    await swipeRowToThreshold();

    assert.dom(".chat-channel-row__action-btn.--remove").exists();
    assert.dom(".chat-channel-row__action-btn .d-icon-circle-xmark").exists();
    assert.true(markAsRead.notCalled, "does not clear notifications for a DM");
  });

  test("channels are not swipeable on touch devices in desktop view", async function (assert) {
    forceTouch(this.owner);

    await render(
      <template>
        <ChatChannelRow @channel={{this.directMessageChannel}} />
      </template>
    );

    await swipeRowToThreshold();

    assert
      .dom(".chat-channel-row__action-btn")
      .doesNotExist("swiping does not reveal the action button");
  });

  test("long-pressing opens the channel menu on touch devices in desktop view", async function (assert) {
    forceTouch(this.owner);

    await render(
      <template>
        <ChatChannelRow @channel={{this.directMessageChannel}} />
        <DMenus />
      </template>
    );

    const event = new Event("touchstart", { bubbles: true });
    event.touches = [{}];
    find(".chat-channel-row").dispatchEvent(event);
    await settled();

    assert
      .dom('.fk-d-menu[data-identifier="chat-direct-message-channel-menu"]')
      .exists("long-press opens the channel menu");
  });
});
