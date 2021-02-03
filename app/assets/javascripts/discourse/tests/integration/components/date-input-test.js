import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

function dateInput() {
  return queryAll(".date-picker")[0];
}

function setDate(date) {
  this.set("date", date);
}

async function pika(year, month, day) {
  await click(
    `.pika-button.pika-day[data-pika-year="${year}"][data-pika-month="${month}"][data-pika-day="${day}"]`
  );
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
      assert.equal(dateInput().value, "January 29, 2019");
    },
  });

  componentTest("prevents mutations", {
    template: hbs`{{date-input date=date onChange=onChange}}`,

    beforeEach() {
      this.setProperties({ date: DEFAULT_DATE });
      this.set("onChange", noop);
    },

    async test(assert) {
      await click(dateInput());
      await pika(2019, 0, 2);

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
      await click(dateInput());
      await pika(2019, 0, 2);

      assert.ok(this.date.isSame(moment("2019-01-02")));
    },
  });
});
