import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

module("Discourse Chat | Component | chat-channel-title", function (hooks) {
  setupRenderingTest(hooks);

  test("category channel", async function (assert) {
    this.channel = fabricators.channel();

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    assert.strictEqual(
      query(".chat-channel-title__category-badge").getAttribute("style"),
      `color: #${this.channel.chatable.color}`
    );
    assert.strictEqual(
      query(".chat-channel-title__name").innerText,
      this.channel.title
    );
  });

  test("category channel - escapes title", async function (assert) {
    this.channel = fabricators.channel({
      chatable_type: CHATABLE_TYPES.categoryChannel,
      title: "<div class='xss'>evil</div>",
    });

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    assert.false(exists(".xss"));
  });

  test("category channel - read restricted", async function (assert) {
    this.channel = fabricators.channel({
      chatable: fabricators.category({ read_restricted: true }),
    });

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    assert.true(exists(".d-icon-lock"));
  });

  test("category channel - not read restricted", async function (assert) {
    this.channel = fabricators.channel({
      chatable: fabricators.category({ read_restricted: false }),
    });

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    assert.false(exists(".d-icon-lock"));
  });

  test("direct message channel - one user", async function (assert) {
    this.channel = fabricators.directMessageChannel({
      chatable: fabricators.directMessage({
        users: [fabricators.user()],
      }),
    });

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    const user = this.channel.chatable.users[0];

    assert.true(exists(`.chat-user-avatar .avatar[title="${user.username}"]`));
    assert.strictEqual(
      query(".chat-channel-title__name").innerText.trim(),
      user.username
    );
  });

  test("direct message channel - multiple users", async function (assert) {
    this.channel = fabricators.directMessageChannel({
      users: [fabricators.user(), fabricators.user(), fabricators.user()],
    });
    this.channel.chatable.group = true;

    await render(hbs`<ChatChannelTitle @channel={{this.channel}} />`);

    const users = this.channel.chatable.users;

    assert.strictEqual(
      parseInt(query(".chat-channel-title__users-count").innerText.trim(), 10),
      users.length
    );
    assert.strictEqual(
      query(".chat-channel-title__name").innerText.trim(),
      users.mapBy("username").join(", ")
    );
  });
});
