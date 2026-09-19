import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ToggleChannelMembershipButton from "discourse/plugins/chat/discourse/components/toggle-channel-membership-button";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ToggleChannelMembershipButton", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  hooks.beforeEach(function () {
    this.showLogin = sinon.stub();
    this.chatStateManager = this.owner.lookup("service:chat-state-manager");
    this.chatStateManager.isDrawerActive = true;
    sinon.stub(this.chatStateManager, "didCloseDrawer");

    this.owner.register(
      "route:application",
      { send: this.showLogin },
      { instantiate: false }
    );

    this.channel = new ChatFabricators(getOwner(this)).channel({
      chatable_type: "Category",
      current_user_membership: null,
      meta: { can_join_chat_channel: true },
    });
  });

  test("anonymous users are sent to login when joining a channel", async function (assert) {
    await render(
      <template>
        <ToggleChannelMembershipButton @channel={{this.channel}} />
      </template>
    );

    assert.dom(".toggle-channel-membership-button.-join").exists();

    await click(".toggle-channel-membership-button.-join");

    assert.true(this.chatStateManager.didCloseDrawer.calledOnce);
    assert.true(this.showLogin.calledWith("showLogin"));
  });
});
