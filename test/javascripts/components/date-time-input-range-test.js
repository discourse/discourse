import componentTest from "helpers/component-test";

moduleForComponent("date-time-input-range", { integration: true });

function fromDateInput() {
  return find(".from.d-date-time-input .date-picker")[0];
}

function fromTimeInput() {
  return find(".from.d-date-time-input .d-time-input .combo-box-header")[0];
}

function toDateInput() {
  return find(".to.d-date-time-input .date-picker")[0];
}

function toTimeInput() {
  return find(".to.d-date-time-input .d-time-input .combo-box-header")[0];
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

componentTest("default", {
  template: `{{date-time-input-range from=from to=to}}`,

  beforeEach() {
    this.setProperties({ from: DEFAULT_DATE_TIME, to: null });
  },

  test(assert) {
    assert.equal(fromDateInput().value, "January 29, 2019");
    assert.equal(fromTimeInput().dataset.name, "14:45");
    assert.equal(toDateInput().value, "");
    assert.equal(toTimeInput().dataset.name, "--:--");
  }
});
