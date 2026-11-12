import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiFeatureSettingToggle from "discourse/plugins/discourse-ai/discourse/components/ai-feature-setting-toggle";

module("Integration | Component | AiFeatureSettingToggle", function (hooks) {
  setupRenderingTest(hooks);

  test("keeps a saved value when the subsequent refresh fails", async function (assert) {
    const saved = [];
    pretender.put("/admin/site_settings/ai_bot_enabled", (request) => {
      saved.push(
        new URLSearchParams(request.requestBody).get("ai_bot_enabled")
      );
      return response({});
    });
    const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
    const setting = tracked({ name: "ai_bot_enabled", value: false });
    const onChange = () => Promise.reject(new Error("Refresh failed"));
    await render(
      <template>
        <AiFeatureSettingToggle
          @label="Enable chatbot"
          @onChange={{onChange}}
          @setting={{setting.value}}
        />
      </template>
    );
    await click(".ai-feature-setting-toggle");
    assert.true(alert.calledOnce, "reports the refresh error");
    assert
      .dom(".ai-feature-setting-toggle")
      .hasAria("checked", "true", "still reflects the successful write");
    await click(".ai-feature-setting-toggle");
    assert.deepEqual(
      saved,
      ["true", "false"],
      "the next toggle uses the saved state, not stale arguments"
    );
    setting.value = { name: "ai_bot_enabled", value: true };
    await settled();
    assert
      .dom(".ai-feature-setting-toggle")
      .hasAria("checked", "true", "a refreshed server value takes precedence");
  });

  test("a failed write leaves the original value", async function (assert) {
    pretender.put("/admin/site_settings/ai_bot_enabled", () =>
      response(422, { errors: ["Cannot enable"] })
    );
    sinon.stub(this.owner.lookup("service:dialog"), "alert");
    const onChange = sinon.stub();
    const setting = { name: "ai_bot_enabled", value: false };
    await render(
      <template>
        <AiFeatureSettingToggle
          @label="Enable chatbot"
          @onChange={{onChange}}
          @setting={{setting}}
        />
      </template>
    );
    await click(".ai-feature-setting-toggle");
    assert
      .dom(".ai-feature-setting-toggle")
      .hasAria("checked", "false", "keeps the original state");
    assert.false(onChange.called, "does not refresh after a failed write");
  });
});
