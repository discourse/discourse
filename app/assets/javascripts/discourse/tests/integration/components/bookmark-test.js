import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | bookmark", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`{{bookmark
        model=model
        afterSave=afterSave
        afterDelete=afterDelete
        onCloseWithoutSaving=onCloseWithoutSaving
        registerOnCloseHandler=registerOnCloseHandler
        closeModal=closeModal}}`;

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

  componentTest("prefills the custom reminder type date and time", {
    template,

    beforeEach() {
      let name = "test";
      let reminderAt = "2020-05-15T09:45:00";
      this.model = { id: 1, name, reminderAt };
    },

    test(assert) {
      assert.strictEqual(query("#bookmark-name").value, "test");
      assert.strictEqual(
        query("#custom-date > .date-picker").value,
        "2020-05-15"
      );
      assert.strictEqual(query("#custom-time").value, "09:45");
    },
  });
});
