import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";
import pretender from "helpers/create-pretender";

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

componentTest("can add a username", {
  template: template(),

  beforeEach() {
    this.set("value", ["bob", "martin"]);

    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    pretender.get("/u/search/users", () => {
      return response({ users: [{ username: "maja", name: "Maja" }] });
    });
  },

  async test(assert) {
    await this.subject.expand();
    await this.subject.fillInFilter("maja");
    await this.subject.keyboard("enter");

    assert.equal(this.subject.header().name(), "bob,martin,maja");
  }
});
