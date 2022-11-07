import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Discourse Chat | Unit | Service | full-page-chat", function (hooks) {
  hooks.beforeEach(function () {
    this.fullPageChat = getOwner(this).lookup("service:full-page-chat");
  });

  hooks.afterEach(function () {
    this.fullPageChat.exit();
  });

  test("defaults", function (assert) {
    assert.strictEqual(this.fullPageChat.isActive, false);
  });

  test("enter", function (assert) {
    this.fullPageChat.enter();
    assert.strictEqual(this.fullPageChat.isActive, true);
  });

  test("exit", function (assert) {
    this.fullPageChat.enter();
    assert.strictEqual(this.fullPageChat.isActive, true);
    this.fullPageChat.exit();
    assert.strictEqual(this.fullPageChat.isActive, false);
  });

  test("previous route", function (assert) {
    const name = "foo";
    const params = { id: 1, slug: "bar" };
    this.fullPageChat.enter({ name, params });
    const routeInfo = this.fullPageChat.exit();

    assert.strictEqual(routeInfo.name, name);
    assert.deepEqual(routeInfo.params, params);
  });
});
