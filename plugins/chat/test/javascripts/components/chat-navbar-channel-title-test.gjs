import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatNavbarChannelTitle from "discourse/plugins/chat/discourse/components/chat/navbar/channel-title";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatNavbar | ChannelTitle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
  });

  test("shows the star button when the user has joined the channel", async function (assert) {
    this.channel = this.fabricators.channel();
    this.channel.currentUserMembership = { following: true };

    await render(
      <template><ChatNavbarChannelTitle @channel={{this.channel}} /></template>
    );

    assert
      .dom(".c-navbar__star-channel-button")
      .exists("the star button is shown");
  });

  test("does not show the star button when the user has not joined the channel", async function (assert) {
    this.channel = this.fabricators.channel();
    this.channel.currentUserMembership = { following: false };

    await render(
      <template><ChatNavbarChannelTitle @channel={{this.channel}} /></template>
    );

    assert
      .dom(".c-navbar__star-channel-button")
      .doesNotExist("the star button is hidden");
  });
});
