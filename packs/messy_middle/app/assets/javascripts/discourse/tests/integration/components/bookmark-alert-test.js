import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | bookmark-alert", function (hooks) {
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

  test("alert exists for reminder in the future", async function (assert) {
    let name = "test";
    let futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 10);

    let reminderAt = futureDate.toISOString();
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

    assert.ok(
      exists(".existing-reminder-at-alert"),
      "alert found for future reminder"
    );
  });

  test("alert does not exist for reminder in the past", async function (assert) {
    let name = "test";
    let pastDate = new Date();
    pastDate.setDate(pastDate.getDate() - 1);

    let reminderAt = pastDate.toISOString();
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

    assert.ok(
      !exists(".existing-reminder-at-alert"),
      "alert not found for past reminder"
    );
  });
});
