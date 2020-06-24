import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";

moduleForComponent("time-input", {
  integration: true,

  beforeEach() {
    this.set("subject", selectKit());
  }
});

function setTime(time) {
  this.setProperties(time);
}

componentTest("default", {
  template: `{{time-input hours=hours minutes=minutes}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
  },

  test(assert) {
    assert.equal(this.subject.header().name(), "14:58");
  }
});

componentTest("prevents mutations", {
  template: `{{time-input hours=hours minutes=minutes}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
  },

  async test(assert) {
    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.equal(this.subject.header().name(), "14:58");
  }
});

componentTest("allows mutations through actions", {
  template: `{{time-input hours=hours minutes=minutes onChange=onChange}}`,

  beforeEach() {
    this.setProperties({ hours: "14", minutes: "58" });
    this.set("onChange", setTime);
  },

  async test(assert) {
    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.equal(this.subject.header().name(), "00:45");
  }
});
