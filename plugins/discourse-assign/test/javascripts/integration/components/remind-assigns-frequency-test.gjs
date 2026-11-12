import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import RemindAssignsFrequency from "discourse/plugins/discourse-assign/discourse/components/remind-assigns-frequency";

module("Integration | Component | RemindAssignsFrequency", function (hooks) {
  setupRenderingTest(hooks);

  test("stores the picked frequency on the user and shows it", async function (assert) {
    this.siteSettings.assign_enabled = true;
    const user = EmberObject.create({
      custom_fields: { remind_assigns_frequency: 1440 },
      reminders_frequency: [
        { name: "Daily", value: 1440 },
        { name: "Weekly", value: 10080 },
      ],
    });

    await render(
      <template><RemindAssignsFrequency @user={{user}} /></template>
    );

    const subject = selectKit("#remind-assigns-frequency");
    assert.strictEqual(subject.header().value(), "1440");

    await subject.expand();
    await subject.selectRowByValue(10080);

    assert.strictEqual(
      user.custom_fields.remind_assigns_frequency,
      10080,
      "stores the frequency on the user"
    );
    assert.strictEqual(
      subject.header().value(),
      "10080",
      "shows the picked frequency"
    );
  });
});
