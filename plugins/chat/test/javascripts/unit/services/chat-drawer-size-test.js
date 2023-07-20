import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Discourse Chat | Unit | Service | chat-drawer-size", function (hooks) {
  hooks.beforeEach(function () {
    this.subject = getOwner(this).lookup("service:chat-drawer-size");
  });

  test("get size (with default)", async function (assert) {
    assert.deepEqual(this.subject.size, { width: 400, height: 530 });
  });

  test("set size", async function (assert) {
    this.subject.size = { width: 400, height: 500 };
    assert.deepEqual(this.subject.size, { width: 400, height: 500 });
  });

  test("min size", async function (assert) {
    this.subject.size = { width: 100, height: 100 };
    assert.deepEqual(this.subject.size, { width: 250, height: 300 });
  });
});
