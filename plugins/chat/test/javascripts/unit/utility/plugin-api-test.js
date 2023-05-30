import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupTest } from "ember-qunit";
import pretender from "discourse/tests/helpers/create-pretender";

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
});
