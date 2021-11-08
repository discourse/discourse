import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function dateInput() {
  return query(".date-picker");
}

function setDate(date) {
  this.set("date", date);
}

function noop() {}

const DEFAULT_DATE = moment("2019-01-29");

discourseModule("Integration | Component | date-input", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{date-input date=date}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE });
    },

    test(assert) {
      assert.strictEqual(dateInput().value, "2019-01-29");
    },
  });

  componentTest("prevents mutations", {
    template: hbs`{{date-input date=date onChange=onChange}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE });
      this.set("onChange", noop);
    },

    async test(assert) {
      dateInput().value = "2019-01-02";
      dateInput().dispatchEvent(new Event("change"));

      assert.ok(this.date.isSame(DEFAULT_DATE));
    },
  });

  componentTest("allows mutations through actions", {
    template: hbs`{{date-input date=date onChange=onChange}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE });
      this.set("onChange", setDate);
    },

    async test(assert) {
      dateInput().value = "2019-02-02";
      dateInput().dispatchEvent(new Event("change"));

      assert.ok(this.date.isSame(moment("2019-02-02")));
    },
  });
});
