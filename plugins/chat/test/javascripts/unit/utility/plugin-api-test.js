import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import pretender from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Utility | plugin-api", function (hooks) {
  setupTest(hooks);

  test("#sendChatMessage", async function (assert) {
    const done = assert.async();

    pretender.post("/chat/1", (request) => {
      assert.strictEqual(request.url, "/chat/1");
      assert.strictEqual(request.requestBody, "thread_id=2&message=hello");
      done();
      return [200, {}, {}];
    });

    withPluginApi(async (api) => {
      await api.sendChatMessage(1, { message: "hello", threadId: 2 });
    });
  });

  test("#removeChatComposerSecondaryActions", async function (assert) {
    withPluginApi(async (api) => {
      // assert that the api method is defined
      assert.strictEqual(
        typeof api.removeChatComposerSecondaryActions,
        "function"
      );

      const user = logIn(this.owner);
      const message = new ChatFabricators(this.owner).message({ user });
      const interactor = new ChatMessageInteractor(
        this.owner,
        message,
        "channel"
      );

      // assert that the initial secondary actions are present
      const secondaryActions = interactor.secondaryActions;
      assert.true(secondaryActions.length > 0);

      api.removeChatComposerSecondaryActions(secondaryActions[0].id);

      assert.deepEqual(
        interactor.secondaryActions.map((v) => v.id),
        secondaryActions.slice(1).map((v) => v.id)
      );
    });
  });

  test("#decorateChatMessage", function (assert) {
    withPluginApi((api) => {
      const calls = [];
      api.decorateChatMessage((element, helper, message) =>
        calls.push([element, helper, message])
      );

      const element = document.createElement("div");
      const helper = {};
      const message = {};
      applyBehaviorTransformer(
        "chat-message-decorate",
        () => calls.push("default"),
        {
          element,
          helper,
          message,
        }
      );

      assert.deepEqual(calls, [[element, helper, message], "default"]);
    });
  });
});
