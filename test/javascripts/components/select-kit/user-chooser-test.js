import componentTest from "helpers/component-test";
import { testSelectKitModule } from "helpers/select-kit-helper";

testSelectKitModule("user-chooser");

function template() {
  return `{{user-chooser value=value}}`;
}

componentTest("displays usernames", {
  template: template(),

  beforeEach() {
    this.set("value", ["bob", "martin"]);
  },

  async test(assert) {
    assert.equal(this.subject.header().name(), "bob,martin");
  }
});

componentTest("can remove a username", {
  template: template(),

  beforeEach() {
    this.set("value", ["bob", "martin"]);
  },

  async test(assert) {
    await this.subject.deselectItem("bob");
    assert.equal(this.subject.header().name(), "martin");
  }
});
