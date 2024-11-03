import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import User from "discourse/models/user";
import pretender from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import ChatMessageInteractor, {
  resetRemovedChatComposerSecondaryActions,
} from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Chat | Unit | Utility | plugin-api", function (hooks) {
  setupTest(hooks);

  test("#sendChatMessage", async function (assert) {
    const done = assert.async();

    pretender.post("/chat/1", (request) => {
      assert.strictEqual(request.url, "/chat/1");
      assert.strictEqual(request.requestBody, "thread_id=2&message=hello");
      done();
      return [200, {}, {}];
    });

    withPluginApi("1.1.0", async (api) => {
      await api.sendChatMessage(1, { message: "hello", threadId: 2 });
    });
  });

  test("#removeChatComposerSecondaryActions", async function (assert) {
    withPluginApi("1.1.0", async (api) => {
      // assert that the api method is defined
      assert.strictEqual(
        typeof api.removeChatComposerSecondaryActions,
        "function"
      );

      logIn();
      const currentUser = User.current();
      getOwner(this).unregister("service:current-user");
      getOwner(this).register("service:current-user", currentUser, {
        instantiate: false,
      });

      const message = new ChatFabricators(getOwner(this)).message({
        user: currentUser,
      });
      const context = "channel";
      const interactor = new ChatMessageInteractor(
        getOwner(this),
        message,
        context
      );

      // assert that the initial secondary actions are present
      const secondaryActions = interactor.secondaryActions;
      assert.ok(secondaryActions.length > 0);

      try {
        // remove the first secondary action listed
        api.removeChatComposerSecondaryActions(secondaryActions[0].id);

        const updatedSecondaryActions = interactor.secondaryActions;

        // assert that the secondary action was removed
        assert.ok(
          updatedSecondaryActions.length < secondaryActions.length,
          "the updated secondary actions must contain less items than the original"
        );
        assert.false(
          updatedSecondaryActions
            .map((v) => v.id)
            .includes(secondaryActions[0]),
          "the updated secondary actions must not include the removed action"
        );
      } finally {
        // reset the secondary actions removed to prevent leakage to other tests
        resetRemovedChatComposerSecondaryActions();
      }
    });
  });
});
