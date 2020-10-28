import { exists } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";
import { click } from "@ember/test-helpers";

moduleForComponent("date-time-input", { integration: true });

function dateInput() {
  return find(".date-picker")[0];
}

function timeInput() {
  return find(".d-time-input .combo-box-header")[0];
}

function setDate(date) {
  this.set("date", date);
}

async function pika(year, month, day) {
  await click(
    `.pika-button.pika-day[data-pika-year="${year}"][data-pika-month="${month}"][data-pika-day="${day}"]`
  );
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

componentTest("default", {
  template: `{{date-time-input date=date}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  test(assert) {
    assert.equal(dateInput().value, "January 29, 2019");
    assert.equal(timeInput().dataset.name, "14:45");
  },
});

componentTest("prevents mutations", {
  template: `{{date-time-input date=date}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  async test(assert) {
    await click(dateInput());
    await pika(2019, 0, 2);

    assert.ok(this.date.isSame(DEFAULT_DATE_TIME));
  },
});

componentTest("allows mutations through actions", {
  template: `{{date-time-input date=date onChange=onChange}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
    this.set("onChange", setDate);
  },

  async test(assert) {
    await click(dateInput());
    await pika(2019, 0, 2);

    assert.ok(this.date.isSame(moment("2019-01-02 14:45")));
  },
});

componentTest("can hide time", {
  template: `{{date-time-input date=date showTime=false}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  async test(assert) {
    assert.notOk(exists(timeInput()));
  },
});
