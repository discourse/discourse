import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function dateInput() {
  return query(".date-picker");
}

function timeInput() {
  return query(".d-time-input .combo-box-header");
}

function setDate(date) {
  this.set("date", date);
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

discourseModule("Integration | Component | date-time-input", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{date-time-input date=date}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE_TIME });
    },

    test(assert) {
      assert.strictEqual(dateInput().value, "2019-01-29");
      assert.strictEqual(timeInput().dataset.name, "14:45");
    },
  });

  componentTest("prevents mutations", {
    template: hbs`{{date-time-input date=date}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE_TIME });
    },

    async test(assert) {
      dateInput().value = "2019-01-02";

      assert.ok(this.date.isSame(DEFAULT_DATE_TIME));
    },
  });

  componentTest("allows mutations through actions", {
    template: hbs`{{date-time-input date=date onChange=onChange}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE_TIME });
      this.set("onChange", setDate);
    },

    async test(assert) {
      dateInput().value = "2019-01-02";
      dateInput().dispatchEvent(new Event("change"));

      assert.ok(this.date.isSame(moment("2019-01-02 14:45")));
    },
  });

  componentTest("can hide time", {
    template: hbs`{{date-time-input date=date showTime=false}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE_TIME });
    },

    async test(assert) {
      assert.notOk(exists(timeInput()));
    },
  });
});
