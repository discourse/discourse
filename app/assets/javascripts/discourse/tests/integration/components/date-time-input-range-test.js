import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function fromDateInput() {
  return queryAll(".from.d-date-time-input .date-picker")[0];
}

function fromTimeInput() {
  return queryAll(".from.d-date-time-input .d-time-input .combo-box-header")[0];
}

function toDateInput() {
  return queryAll(".to.d-date-time-input .date-picker")[0];
}

function toTimeInput() {
  return queryAll(".to.d-date-time-input .d-time-input .combo-box-header")[0];
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

discourseModule(
  "Integration | Component | date-time-input-range",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("default", {
      template: hbs`{{date-time-input-range from=from to=to}}`,

      beforeEach() {
        this.setProperties({ from: DEFAULT_DATE_TIME, to: null });
      },

      test(assert) {
        assert.equal(fromDateInput().value, "January 29, 2019");
        assert.equal(fromTimeInput().dataset.name, "14:45");
        assert.equal(toDateInput().value, "");
        assert.equal(toTimeInput().dataset.name, "--:--");
      },
    });
  }
);
