import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  fakeTime,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import sinon from "sinon";

let clock = null;

function mockMomentTz(dateString, timezone) {
  clock = fakeTime(dateString, timezone, true);
}

discourseModule("Integration | Component | bookmark", function (hooks) {
  setupRenderingTest(hooks);

  let template =
    '{{bookmark model=model afterSave=afterSave afterDelete=afterDelete onCloseWithoutSaving=onCloseWithoutSaving registerOnCloseHandler=(action "registerOnCloseHandler") closeModal=(action "closeModal")}}';

  hooks.beforeEach(function () {
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
    template,
    skip: true,

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
      template,
      skip: true,

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
    template,
    skip: true,

    beforeEach() {
      mockMomentTz("2019-12-11T22:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.notOk(
        exists("#tap_tile_later_today"),
        "it does not have later today"
      );
    },
  });

  componentTest("later today shows if it is after 5pm but before 6pm", {
    template,
    skip: true,

    beforeEach() {
      mockMomentTz("2019-12-11T14:30:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("later today does not show if it is after 5pm", {
    template,
    skip: true,

    beforeEach() {
      mockMomentTz("2019-12-11T17:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.notOk(
        exists("#tap_tile_later_today"),
        "it does not have later today"
      );
    },
  });

  componentTest("later today does show if it is before the end of the day", {
    template,
    skip: true,

    beforeEach() {
      mockMomentTz("2019-12-11T13:00:00", this.currentUser._timezone);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("prefills the custom reminder type date and time", {
    template,
    skip: true,

    beforeEach() {
      let name = "test";
      let reminderAt = "2020-05-15T09:45:00";
      this.model = { id: 1, name, reminderAt };
    },

    test(assert) {
      assert.equal(query("#bookmark-name").value, "test");
      assert.equal(query("#custom-date > .date-picker").value, "2020-05-15");
      assert.equal(query("#custom-time").value, "09:45");
    },
  });

  componentTest("defaults to 08:00 for custom time", {
    template,
    skip: true,

    async test(assert) {
      await click("#tap_tile_custom");
      assert.equal(query("#custom-time").value, "08:00");
    },
  });
});
