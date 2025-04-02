import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.channel.description =
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
  });

  test("escapes channel title", async function (assert) {
    this.channel.title = "<div class='xss'>evil</div>";

    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".xss").doesNotExist();
  });

  test("escapes channel description", async function (assert) {
    this.channel.description = "<div class='xss'>evil</div>";

    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".xss").doesNotExist();
  });

  test("Closed channel", async function (assert) {
    this.channel.status = "closed";
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card.--closed").exists();
  });

  test("Archived channel", async function (assert) {
    this.channel.status = "archived";
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card.--archived").exists();
  });

  test("Muted channel", async function (assert) {
    this.channel.currentUserMembership.muted = true;
    this.channel.currentUserMembership.following = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card__muted").exists();
  });

  test("Joined channel", async function (assert) {
    this.channel.currentUserMembership.following = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);
    assert.dom(".toggle-channel-membership-button.-leave").exists();
  });

  test("Joinable channel", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card__join-btn").exists();
  });

  test("Memberships count", async function (assert) {
    this.channel.membershipsCount = 4;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel-card__members")
      .hasText(i18n("chat.channel.memberships_count", { count: 4 }));
  });

  test("No description", async function (assert) {
    this.channel.description = null;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card__description").doesNotExist();
  });

  test("Description", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel-card__description")
      .hasText(this.channel.description);
  });

  test("Name", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card__name").hasText(this.channel.title);
  });

  test("Read restricted chatable", async function (assert) {
    this.channel.chatable.read_restricted = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);
    assert.dom(".d-icon-lock").exists();
  });
});
