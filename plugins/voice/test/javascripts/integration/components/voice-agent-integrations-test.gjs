import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import VoiceAgentIntegrations from "discourse/plugins/voice/admin/components/voice-agent-integrations";

module("Integration | Component | VoiceAgentIntegrations", function (hooks) {
  setupRenderingTest(hooks);

  test("creates a scoped integration and reveals its credential", async function (assert) {
    this.model = {
      integrations: [],
      bots: [{ id: -1400, username: "assistant" }],
      rooms: [{ id: 1, name: "Lounge" }],
    };
    pretender.post("/admin/plugins/voice/agent-integrations", (request) => {
      const params = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        params.get("integration[bot_user_id]"),
        "-1400",
        "selects the bot account"
      );
      assert.strictEqual(
        params.get("integration[room_ids][]"),
        "1",
        "scopes the credential to the selected room"
      );
      return response({
        integration: {
          id: 1,
          name: "Assistant",
          bot_user: this.model.bots[0],
          room_ids: [1],
          role: "speaker",
          excluded_room_ids: [],
        },
        credential: "one-time-secret",
      });
    });

    await render(
      <template><VoiceAgentIntegrations @model={{this.model}} /></template>
    );
    await formKit().field("name").fillIn("Assistant");
    await formKit().field("bot_user_id").select("-1400");
    await click('input[name="room_1"]');
    await formKit().field("role").select("speaker");
    await formKit().submit();

    assert
      .dom(".voice-agent-integrations__credential")
      .includesText("one-time-secret", "shows the new credential");
    assert
      .dom(".d-table__body")
      .includesText("assistant", "shows the assigned bot");
    assert
      .dom(".d-table__body")
      .includesText("Lounge", "shows the allowed room name");
    assert.dom(".d-table__body").includesText("Speaker", "shows the role");
  });
});
