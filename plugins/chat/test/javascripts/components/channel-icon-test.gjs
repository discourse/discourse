import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

module("Discourse Chat | Component | <ChannelIcon />", function (hooks) {
  setupRenderingTest(hooks);

  test("category channel - badge", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.strictEqual(
      query(".chat-channel-icon.--category-badge").getAttribute("style"),
      `color: #${channel.chatable.color}`
    );
  });

  test("category channel - escapes label", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel({
      chatable_type: CHATABLE_TYPES.categoryChannel,
      title: "<div class='xss'>evil</div>",
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.false(exists(".xss"));
  });

  test("category channel - read restricted", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel({
      chatable: new CoreFabricators(getOwner(this)).category({
        read_restricted: true,
      }),
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.dom(".d-icon-lock").exists();
  });

  test("category channel - not read restricted", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel({
      chatable: new CoreFabricators(getOwner(this)).category({
        read_restricted: false,
      }),
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.false(exists(".d-icon-lock"));
  });

  test("dm channel - one user", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).directMessageChannel({
      chatable: new ChatFabricators(getOwner(this)).directMessage({
        users: [new CoreFabricators(getOwner(this)).user()],
      }),
    });
    const user = channel.chatable.users[0];

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.dom(`.chat-user-avatar .avatar[title="${user.username}"]`).exists();
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

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.strictEqual(
      parseInt(query(".chat-channel-icon.--users-count").innerText.trim(), 10),
      users.length
    );
  });
});
