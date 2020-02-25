import componentTest from "helpers/component-test";

moduleForComponent("date-time-input-range", { integration: true });

function fromDateInput() {
  return find(".from .date-picker");
}

function fromHoursInput() {
  return find(".from .field.hours");
}

function fromMinutesInput() {
  return find(".from .field.minutes");
}

function toDateInput() {
  return find(".to .date-picker");
}

function toHoursInput() {
  return find(".to .field.hours");
}

function toMinutesInput() {
  return find(".to .field.minutes");
}

function setDates(dates) {
  this.setProperties(dates);
}

async function pika(year, month, day) {
  await click(
    `.pika-button.pika-day[data-pika-year="${year}"][data-pika-month="${month}"][data-pika-day="${day}"]`
  );
}

const DEFAULT_DATE_TIME = new Date(2019, 0, 29, 14, 45);

componentTest("default", {
  template: `{{date-time-input-range from=from to=to}}`,

  beforeEach() {
    this.setProperties({ from: DEFAULT_DATE_TIME, to: null });
  },

  test(assert) {
    assert.equal(fromDateInput().val(), "January 29, 2019");
    assert.equal(fromHoursInput().val(), "14");
    assert.equal(fromMinutesInput().val(), "45");

    assert.equal(toDateInput().val(), "");
    assert.equal(toHoursInput().val(), "");
    assert.equal(toMinutesInput().val(), "");
  }
});

componentTest("can switch panels", {
  template: `{{date-time-input-range}}`,

  async test(assert) {
    assert.ok(exists(".panel.from.visible"));
    assert.notOk(exists(".panel.to.visible"));

    await click(".panels button.to-panel");

    assert.ok(exists(".panel.to.visible"));
    assert.notOk(exists(".panel.from.visible"));
  }
});

componentTest("prevents toDate to be before fromDate", {
  template: `{{date-time-input-range from=from to=to onChange=onChange}}`,

  beforeEach() {
    this.setProperties({
      from: DEFAULT_DATE_TIME,
      to: DEFAULT_DATE_TIME,
      onChange: setDates
    });
  },

  async test(assert) {
    assert.notOk(exists(".error"), "it begins with no error");

    await click(".panels button.to-panel");
    await click(toDateInput());
    await pika(2019, 0, 1);

    assert.ok(exists(".error"), "it shows an error");
    assert.deepEqual(this.to, DEFAULT_DATE_TIME, "it didnt trigger a mutation");

    await click(".panels button.to-panel");
    await click(toDateInput());
    await pika(2019, 0, 30);

    assert.notOk(exists(".error"), "it removes the error");
    assert.deepEqual(
      this.to,
      new Date(2019, 0, 30, 14, 45),
      "it has changed the date"
    );
  }
});
