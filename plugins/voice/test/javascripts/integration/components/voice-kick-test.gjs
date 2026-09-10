import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import VoiceKick from "discourse/plugins/voice/discourse/components/modal/voice-kick";

module("Integration | Component | VoiceKick", function (hooks) {
  setupRenderingTest(hooks);

  test("offers an indefinite exclusion", async function (assert) {
    this.closeModal = (result) =>
      assert.deepEqual(
        result,
        { duration: 0 },
        "returns the indefinite duration"
      );
    await render(
      <template>
        <VoiceKick @closeModal={{this.closeModal}} @inline={{true}} />
      </template>
    );
    await formKit().field("duration").select("0");
    await formKit().submit();
  });
});
