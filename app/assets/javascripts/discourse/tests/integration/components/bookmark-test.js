import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | bookmark", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.setProperties({
      model: {},
      closeModal: () => {},
      afterSave: () => {},
      afterDelete: () => {},
      registerOnCloseHandler: () => {},
      onCloseWithoutSaving: () => {},
    });
  });

  test("prefills the custom reminder type date and time", async function (assert) {
    let name = "test";
    let reminderAt = "2020-05-15T09:45:00";
    this.model = { id: 1, name, reminderAt };

    await render(hbs`
      <Bookmark
        @model={{this.model}}
        @afterSave={{this.afterSave}}
        @afterDelete={{this.afterDelete}}
        @onCloseWithoutSaving={{this.onCloseWithoutSaving}}
        @registerOnCloseHandler={{this.registerOnCloseHandler}}
        @closeModal={{this.closeModal}}
      />
    `);

    assert.strictEqual(query("#bookmark-name").value, "test");
    assert.strictEqual(
      query("#custom-date > .date-picker").value,
      "2020-05-15"
    );
    assert.strictEqual(query("#custom-time").value, "09:45");
  });
});
