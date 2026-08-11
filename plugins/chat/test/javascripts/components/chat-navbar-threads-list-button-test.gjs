import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatNavbarThreadsListButton from "discourse/plugins/chat/discourse/components/chat/navbar/threads-list-button";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatNavbar | ThreadsListButton", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
    this.chatStateManager = getOwner(this).lookup("service:chat-state-manager");
    this.channel = this.fabricators.channel();
    this.channel.threadingEnabled = true;
  });

  test("shows the threads list button when threading is enabled", async function (assert) {
    await render(
      <template>
        <ChatNavbarThreadsListButton @channel={{this.channel}} />
      </template>
    );

    assert
      .dom(".c-navbar__threads-list-button")
      .exists("the threads list button is shown");
  });

  test("does not show the threads list button when the drawer is collapsed", async function (assert) {
    this.chatStateManager.didCollapseDrawer();

    await render(
      <template>
        <ChatNavbarThreadsListButton @channel={{this.channel}} />
      </template>
    );

    assert
      .dom(".c-navbar__threads-list-button")
      .doesNotExist("the threads list button is hidden");
  });
});
