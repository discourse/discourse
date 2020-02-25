import componentTest from "helpers/component-test";

moduleForComponent("date-input", { integration: true });

function dateInput() {
  return find(".date-picker");
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

const DEFAULT_DATE = new Date(2019, 0, 29);

componentTest("default", {
  template: `{{date-input date=date}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE });
  },

  test(assert) {
    assert.equal(dateInput().val(), "January 29, 2019");
  }
});

componentTest("prevents mutations", {
  template: `{{date-input date=date onChange=onChange}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", noop);
  },

  async test(assert) {
    await click(dateInput());
    await pika(2019, 0, 2);

    assert.ok(this.date.getTime() === DEFAULT_DATE.getTime());
  }
});

componentTest("allows mutations through actions", {
  template: `{{date-input date=date onChange=onChange}}`,

  beforeEach() {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", setDate);
  },

  async test(assert) {
    await click(dateInput());
    await pika(2019, 0, 2);

    assert.ok(this.date.getTime() === new Date(2019, 0, 2).getTime());
  }
});
