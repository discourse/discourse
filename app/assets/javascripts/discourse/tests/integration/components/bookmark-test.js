import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  fakeTime,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
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

  hooks.afterEach(function () {
    if (this.clock) {
      this.clock.restore();
    }
  });

  componentTest("shows correct options", {
    template,

    beforeEach() {
      const tuesday = "2100-06-08T08:00:00";
      this.clock = fakeTime(tuesday, this.currentUser._timezone, true);
    },

    async test(assert) {
      const expected = [
        I18n.t("time_shortcut.later_today"),
        I18n.t("time_shortcut.tomorrow"),
        I18n.t("time_shortcut.later_this_week"),
        I18n.t("time_shortcut.start_of_next_business_week"),
        I18n.t("time_shortcut.next_month"),
        I18n.t("time_shortcut.custom"),
        I18n.t("time_shortcut.none"),
      ];

      const options = Array.from(
        queryAll(
          "div.control-group div.tap-tile-grid div.tap-tile-title"
        ).map((_, div) => div.innerText.trim())
      );

      assert.deepEqual(options, expected);
    },
  });

  componentTest("show later this week option if today is < Thursday", {
    template,

    beforeEach() {
      const monday = "2100-06-07T08:00:00";
      this.clock = fakeTime(monday, this.currentUser._timezone, true);
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_this_week"), "it has later this week");
    },
  });

  componentTest(
    "does not show later this week option if today is >= Thursday",
    {
      template,

      beforeEach() {
        const thursday = "2100-06-10T08:00:00";
        this.clock = fakeTime(thursday, this.currentUser._timezone, true);
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

    beforeEach() {
      this.clock = fakeTime(
        "2100-12-11T22:00:00",
        this.currentUser._timezone,
        true
      );
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

    beforeEach() {
      this.clock = fakeTime(
        "2100-12-11T14:30:00",
        this.currentUser._timezone,
        true
      );
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("later today does not show if it is after 5pm", {
    template,

    beforeEach() {
      this.clock = fakeTime(
        "2100-12-11T17:00:00",
        this.currentUser._timezone,
        true
      );
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

    beforeEach() {
      this.clock = fakeTime(
        "2100-12-11T13:00:00",
        this.currentUser._timezone,
        true
      );
    },

    test(assert) {
      assert.ok(exists("#tap_tile_later_today"), "it does have later today");
    },
  });

  componentTest("prefills the custom reminder type date and time", {
    template,

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

    async test(assert) {
      await click("#tap_tile_custom");
      assert.equal(query("#custom-time").value, "08:00");
    },
  });

  componentTest("Next Month points to the first day of the next month", {
    template,

    beforeEach() {
      this.clock = fakeTime(
        "2100-01-01T08:00:00",
        this.currentUser._timezone,
        true
      );
    },

    async test(assert) {
      assert.equal(
        query("div#tap_tile_next_month div.tap-tile-date").innerText,
        "Feb 1, 8:00 am"
      );
    },
  });
});
