import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupTest } from "ember-qunit";
import pretender from "discourse/tests/helpers/create-pretender";

module("Chat | Unit | Utility | plugin-api", function (hooks) {
  setupTest(hooks);

  test("#sendChatMessage", function (assert) {
    pretender.post("/chat/1", (request) => {
      assert.strictEqual(request.url, "/chat/1");
      assert.strictEqual(request.requestBody, "message=hello&thread_id=2");
      return [200, {}, {}];
    });

    withPluginApi("1.1.0", (api) => {
      api.sendChatMessage(1, { message: "hello", thread_id: 2 });
    });
  });
});
