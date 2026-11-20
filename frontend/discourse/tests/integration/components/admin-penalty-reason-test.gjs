import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminPenaltyReason from "discourse/admin/components/admin-penalty-reason";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | AdminPenaltyReason", function (hooks) {
  setupRenderingTest(hooks);

  test("reports the reason and the message", async function (assert) {
    const reasons = [];
    const messages = [];
    const changeReason = (value) => reasons.push(value);
    const changeMessage = (value) => messages.push(value);

    await render(
      <template>
        <AdminPenaltyReason
          @message="initial message"
          @onChangeMessage={{changeMessage}}
          @onChangeReason={{changeReason}}
          @penaltyType="suspend"
        />
      </template>
    );

    assert.dom(".suspend-message").hasValue("initial message");

    await fillIn("input.suspend-reason", "custom reason");
    await selectKit(".suspend-reason").expand();
    await selectKit(".suspend-reason").selectRowByValue("combative");
    await fillIn(".suspend-message", "a message");

    assert.deepEqual(
      reasons,
      ["custom reason", i18n("admin.user.suspend_reasons.combative")],
      "reports the typed and the picked reason"
    );
    assert.deepEqual(messages, ["a message"], "reports the message");
  });
});
