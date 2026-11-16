import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Routes | chat | design-wizard", function (hooks) {
  setupTest(hooks);

  test("previews the chat homepage full page while preserving the drawer preference", function (assert) {
    const route = this.owner.lookup("route:chat");
    const sandbox = sinon.createSandbox();

    try {
      sandbox.stub(route.chat, "chatDisabledInPreferences").get(() => false);
      sandbox.stub(route.chat, "userCanChat").get(() => true);
      sandbox.stub(route.chatStateManager, "isDrawerPreferred").get(() => true);
      sandbox.stub(route.chatDrawerRouter, "canHandleRoute").returns(true);
      const trigger = sandbox.stub(route.appEvents, "trigger");
      const transition = {
        to: { name: "chat.channel" },
        from: { name: "discovery.latest" },
        targetName: "chat.channel",
        intent: { url: "/chat/c/general/1" },
        abort: sandbox.stub(),
      };

      route.designWizard.active = true;
      route.designWizard.homepage = "chat";
      route.beforeModel(transition);

      assert.false(
        transition.abort.called,
        "allows the full page transition during preview"
      );
      assert.true(
        trigger.calledWith("chat:toggle-close"),
        "closes any existing drawer"
      );

      route.designWizard.active = false;
      trigger.resetHistory();
      route.beforeModel(transition);

      assert.true(
        transition.abort.calledOnce,
        "normal navigation still uses the drawer"
      );
      assert.true(
        trigger.calledWith("chat:open-url", "/chat/c/general/1"),
        "opens the requested channel in the drawer"
      );
    } finally {
      sandbox.restore();
    }
  });
});
