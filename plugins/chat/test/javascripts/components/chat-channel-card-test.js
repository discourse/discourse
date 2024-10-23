import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
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

    assert.false(exists(".xss"));
  });

  test("escapes channel description", async function (assert) {
    this.channel.description = "<div class='xss'>evil</div>";

    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.false(exists(".xss"));
  });

  test("Closed channel", async function (assert) {
    this.channel.status = "closed";
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.true(exists(".chat-channel-card.--closed"));
  });

  test("Archived channel", async function (assert) {
    this.channel.status = "archived";
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.true(exists(".chat-channel-card.--archived"));
  });

  test("Muted channel", async function (assert) {
    this.channel.currentUserMembership.muted = true;
    this.channel.currentUserMembership.following = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.true(exists(".chat-channel-card__muted"));
  });

  test("Joined channel", async function (assert) {
    this.channel.currentUserMembership.following = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);
    assert.true(exists(".toggle-channel-membership-button.-leave"));
  });

  test("Joinable channel", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.true(exists(".chat-channel-card__join-btn"));
  });

  test("Memberships count", async function (assert) {
    this.channel.membershipsCount = 4;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.strictEqual(
      query(".chat-channel-card__members").textContent.trim(),
      I18n.t("chat.channel.memberships_count", { count: 4 })
    );
  });

  test("No description", async function (assert) {
    this.channel.description = null;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.false(exists(".chat-channel-card__description"));
  });

  test("Description", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.strictEqual(
      query(".chat-channel-card__description").textContent.trim(),
      this.channel.description
    );
  });

  test("Name", async function (assert) {
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);

    assert.dom(".chat-channel-card__name").hasText(this.channel.title);
  });

  test("Read restricted chatable", async function (assert) {
    this.channel.chatable.read_restricted = true;
    await render(hbs`<ChatChannelCard @channel={{this.channel}} />`);
    assert.true(exists(".d-icon-lock"));
  });
});
