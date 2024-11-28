import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | header", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.header = getOwner(this).lookup("service:header");
  });

  test("it registers hiders", function (assert) {
    this.header.registerHider(this, ["search", "login"]);
    assert.true(this.header.headerButtonsHidden.includes("search"));
    assert.true(this.header.headerButtonsHidden.includes("login"));
  });

  test("it does not register invalid buttons for hiders", function (assert) {
    this.header.registerHider(this, ["search", "blahblah"]);
    assert.false(this.header.headerButtonsHidden.includes("blah"));
  });
});
