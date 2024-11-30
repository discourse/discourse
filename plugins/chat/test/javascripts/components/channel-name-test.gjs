import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChannelName from "discourse/plugins/chat/discourse/components/channel-name";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

const CHANNEL_NAME_LABEL = ".chat-channel-name__label";

module("Discourse Chat | Component | <ChannelName />", function (hooks) {
  setupRenderingTest(hooks);

  test("category channel - label", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(CHANNEL_NAME_LABEL).hasText(channel.title);
  });

  test("category channel - escapes label", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel({
      chatable_type: CHATABLE_TYPES.categoryChannel,
      title: "<div class='xss'>evil</div>",
    });

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(".xss").doesNotExist();
  });

  test("dm channel - one user", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).directMessageChannel({
      chatable: new ChatFabricators(getOwner(this)).directMessage({
        users: [new CoreFabricators(getOwner(this)).user()],
      }),
    });
    const user = channel.chatable.users[0];

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(CHANNEL_NAME_LABEL).hasText(user.username);
  });

  test("dm channel - multiple users", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).directMessageChannel({
      users: [
        new CoreFabricators(getOwner(this)).user(),
        new CoreFabricators(getOwner(this)).user(),
        new CoreFabricators(getOwner(this)).user(),
      ],
    });
    channel.chatable.group = true;
    const users = channel.chatable.users;

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(CHANNEL_NAME_LABEL).hasText(users.mapBy("username").join(", "));
  });

  test("dm channel - self", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).directMessageChannel({
      chatable: new ChatFabricators(getOwner(this)).directMessage({
        users: [],
      }),
    });

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(CHANNEL_NAME_LABEL).hasText(this.currentUser.username);
  });

  test("dm channel - prefers name", async function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.enable_names = true;
    siteSettings.display_name_on_posts = true;
    siteSettings.prioritize_username_in_ux = false;

    const channel = new ChatFabricators(getOwner(this)).directMessageChannel({
      users: [
        new CoreFabricators(getOwner(this)).user({ name: "Alice" }),
        new CoreFabricators(getOwner(this)).user({ name: "Bob" }),
      ],
    });
    channel.chatable.group = true;
    const users = channel.chatable.users;

    await render(<template><ChannelName @channel={{channel}} /></template>);

    assert.dom(CHANNEL_NAME_LABEL).hasText(users.mapBy("name").join(", "));
  });

  test("unreadIndicator", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).directMessageChannel();
    channel.tracking.unreadCount = 1;

    let unreadIndicator = true;
    await render(<template>
      <ChannelName @channel={{channel}} @unreadIndicator={{unreadIndicator}} />
    </template>);

    assert.dom(".chat-channel-unread-indicator").exists();

    unreadIndicator = false;
    await render(<template>
      <ChannelName @channel={{channel}} @unreadIndicator={{unreadIndicator}} />
    </template>);

    assert.dom(".chat-channel-unread-indicator").doesNotExist();
  });
});
