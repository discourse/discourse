import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function fromDateInput() {
  return query(".from.d-date-time-input .date-picker");
}

function fromTimeInput() {
  return query(".from.d-date-time-input .d-time-input .combo-box-header");
}

function toDateInput() {
  return query(".to.d-date-time-input .date-picker");
}

function toTimeInput() {
  return query(".to.d-date-time-input .d-time-input .combo-box-header");
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
        assert.strictEqual(fromDateInput().value, "2019-01-29");
        assert.strictEqual(fromTimeInput().dataset.name, "14:45");
        assert.strictEqual(toDateInput().value, "");
        assert.strictEqual(toTimeInput().dataset.name, "--:--");
      },
    });
  }
);
