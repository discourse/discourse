import componentTest from "helpers/component-test";

moduleForComponent("time-input", { integration: true });

function hoursInput() {
  return find(".field.hours");
}

function minutesInput() {
  return find(".field.minutes");
}

function setTime(time) {
  this.setProperties(time);
}

function noop() {}

componentTest("default", {
  template: `{{time-input hours=hours minutes=minutes}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
  },

  test(assert) {
    assert.equal(hoursInput().val(), "14");
    assert.equal(minutesInput().val(), "58");
  }
});

componentTest("prevents mutations", {
  template: `{{time-input hours=hours minutes=minutes}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
  },

  async test(assert) {
    await fillIn(hoursInput(), "12");
    assert.ok(this.hours === "14");

    await fillIn(minutesInput(), "36");
    assert.ok(this.minutes === "58");
  }
});

componentTest("allows mutations through actions", {
  template: `{{time-input hours=hours minutes=minutes onChange=onChange}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
    this.set("onChange", setTime);
  },

  async test(assert) {
    await fillIn(hoursInput(), "12");
    assert.ok(this.hours === "12");

    await fillIn(minutesInput(), "36");
    assert.ok(this.minutes === "36");
  }
});

componentTest("hours and minutes have boundaries", {
  template: `{{time-input hours=14 minutes=58 onChange=onChange}}`,

  beforeEach() {
    this.set("onChange", noop);
  },

  async test(assert) {
    await fillIn(hoursInput(), "2");
    assert.equal(hoursInput().val(), "02");

    await fillIn(hoursInput(), "@");
    assert.equal(hoursInput().val(), "00");

    await fillIn(hoursInput(), "24");
    assert.equal(hoursInput().val(), "23");

    await fillIn(hoursInput(), "-1");
    assert.equal(hoursInput().val(), "00");

    await fillIn(minutesInput(), "@");
    assert.equal(minutesInput().val(), "00");

    await fillIn(minutesInput(), "2");
    assert.equal(minutesInput().val(), "02");

    await fillIn(minutesInput(), "60");
    assert.equal(minutesInput().val(), "59");

    await fillIn(minutesInput(), "-1");
    assert.equal(minutesInput().val(), "00");
  }
});
