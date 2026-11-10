import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import UserDateOfBirthInput from "discourse/plugins/discourse-cakeday/discourse/connectors/user-custom-preferences/user-date-of-birth-input";

module("Integration | Component | UserDateOfBirthInput", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the birthdate and records changes", async function (assert) {
    this.siteSettings.cakeday_birthday_enabled = true;
    const model = EmberObject.create({ birthdate: "1904-03-05" });

    await render(
      <template><UserDateOfBirthInput @model={{model}} /></template>
    );

    const month = selectKit(".controls .combo-box:first-child");
    const day = selectKit(".controls .combo-box:last-child");
    assert.strictEqual(month.header().value(), "3", "shows the month");
    assert.strictEqual(day.header().value(), "5", "shows the day");

    await day.expand();
    await day.selectRowByValue("17");

    assert.strictEqual(
      model.date_of_birth,
      "1904-3-17",
      "records the new birthdate"
    );

    await month.expand();
    await month.selectRowByValue(11);

    assert.strictEqual(model.date_of_birth, "1904-11-17");
  });
});
