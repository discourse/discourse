import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import KeyboardShortcutInitializer from "discourse/initializers/keyboard-shortcuts";
import { getApplication } from "@ember/test-helpers";
import sinon from "sinon";

let clock = null;

// note: dateString should be in UTC time, and will be translated to
// the provided timezone time
function mockMomentTz(dateString, timezone) {
  clock = fakeTime(dateString, timezone, true);
}

discourseModule("Integration | Component | bookmark", function (hooks) {
  setupRenderingTest(hooks);

  let template =
    '{{bookmark model=model afterSave=afterSave afterDelete=afterDelete onCloseWithoutSaving=onCloseWithoutSaving registerOnCloseHandler=(action "registerOnCloseHandler") closeModal=(action "closeModal")}}';

  hooks.beforeEach(function () {
    KeyboardShortcutInitializer.initialize(getApplication());
    this.actions.registerOnCloseHandler = () => {};
    this.actions.closeModal = () => {};
    this.setProperties({
      model: {},
      afterSave: () => {},
      afterDelete: () => {},
      onCloseWithoutSaving: () => {},
    });
  });

  hooks.afterEach(function () {
    if (clock) {
      clock.restore();
    }
    sinon.restore();
  });

  componentTest("show later this week option if today is < Thursday", {
    template: template,

    beforeEach() {
      mockMomentTz("2019-12-10T08:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_this_week"), "it has later this week");
    },
  });

  componentTest(
    "does not show later this week option if today is >= Thursday",
    {
      template: template,

      beforeEach() {
        mockMomentTz("2019-12-13T08:00:00", this.currentUser._timezone);
      },

      test(assert) {
        assert.notOk(
          exists("#tap_tile_later_this_week"),
          "it does not have later this week"
        );
      },
    }
  );

  componentTest("later today does not show if later today is tomorrow", {
    template: template,

    beforeEach() {
      // 10PM + 3h is 1am
      mockMomentTz("2019-12-11T12:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.notOk(
        exists("#tap_tile_later_today"),
        "it does not have later today"
      );
    },
  });

  componentTest("later today shows if it is after 5pm but before 6pm", {
    template: template,

    beforeEach() {
      mockMomentTz("2019-12-11T04:30:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("later today does not show if it is after 5pm", {
    template: template,

    beforeEach() {
      mockMomentTz("2019-12-11T07:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.notOk(
        exists("#tap_tile_later_today"),
        "it does not have later today"
      );
    },
  });

  componentTest("later today does show if it is before the end of the day", {
    template: template,

    beforeEach() {
      mockMomentTz("2019-12-11T03:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("prefills the custom reminder type date and time", {
    template: template,

    beforeEach() {
      let name = "test";
      let reminderAt = "2020-05-15T09:45:00";
      this.model = { id: 1, name: name, reminderAt: reminderAt };
    },

    test(assert) {
      assert.equal(queryAll("#bookmark-name")[0].value, "test");
      assert.equal(
        queryAll("#custom-date > .date-picker")[0].value,
        "2020-05-15"
      );
      assert.equal(queryAll("#custom-time")[0].value, "09:45");
    },
  });

  componentTest("defaults to 08:00 for custom time", {
    template: template,

    async test(assert) {
      await click("#tap_tile_custom");
      assert.equal(queryAll("#custom-time")[0].value, "08:00");
    },
  });
});
