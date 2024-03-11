import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

module("Discourse Chat | Component | <ChannelIcon />", function (hooks) {
  setupRenderingTest(hooks);

  test("category channel - badge", async function (assert) {
    const channel = fabricators.channel();

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.strictEqual(
      query(".chat-channel-icon.--category-badge").getAttribute("style"),
      `color: #${channel.chatable.color}`
    );
  });

  test("category channel - escapes label", async function (assert) {
    const channel = fabricators.channel({
      chatable_type: CHATABLE_TYPES.categoryChannel,
      title: "<div class='xss'>evil</div>",
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.false(exists(".xss"));
  });

  test("category channel - read restricted", async function (assert) {
    const channel = fabricators.channel({
      chatable: fabricators.category({ read_restricted: true }),
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.true(exists(".d-icon-lock"));
  });

  test("category channel - not read restricted", async function (assert) {
    const channel = fabricators.channel({
      chatable: fabricators.category({ read_restricted: false }),
    });

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.false(exists(".d-icon-lock"));
  });

  test("dm channel - one user", async function (assert) {
    const channel = fabricators.directMessageChannel({
      chatable: fabricators.directMessage({
        users: [fabricators.user()],
      }),
    });
    const user = channel.chatable.users[0];

    await render(<template><ChannelIcon @channel={{channel}} /></template>);

    assert.true(exists(`.chat-user-avatar .avatar[title="${user.username}"]`));
  });

  test("dm channel - multiple users", async function (assert) {
    const channel = fabricators.directMessageChannel({
      users: [fabricators.user(), fabricators.user(), fabricators.user()],
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
