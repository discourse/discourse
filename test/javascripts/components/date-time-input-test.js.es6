import componentTest from "helpers/component-test";

moduleForComponent("date-time-input", { integration: true });

function dateInput() {
  return find(".date-picker");
}

function hoursInput() {
  return find(".field.hours");
}

function minutesInput() {
  return find(".field.minutes");
}

function setDate(date) {
  this.set("date", date);
}

async function pika(year, month, day) {
  await click(
    `.pika-button.pika-day[data-pika-year="${year}"][data-pika-month="${month}"][data-pika-day="${day}"]`
  );
}

const DEFAULT_DATE_TIME = new Date(2019, 0, 29, 14, 45);

componentTest("default", {
  template: `{{date-time-input date=date}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  test(assert) {
    assert.equal(dateInput().val(), "January 29, 2019");
    assert.equal(hoursInput().val(), "14");
    assert.equal(minutesInput().val(), "45");
  }
});

componentTest("prevents mutations", {
  template: `{{date-time-input date=date}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  async test(assert) {
    await click(dateInput());
    await pika(2019, 0, 2);

    assert.ok(this.date.getTime() === DEFAULT_DATE_TIME.getTime());
  }
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

    assert.ok(this.date.getTime() === new Date(2019, 0, 2, 14, 45).getTime());
  }
});

componentTest("can hide time", {
  template: `{{date-time-input date=date showTime=false}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE_TIME });
  },

  async test(assert) {
    assert.notOk(exists(hoursInput()));
  }
});
