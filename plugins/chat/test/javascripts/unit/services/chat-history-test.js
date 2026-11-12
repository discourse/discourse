import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | chat-history", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.subject = getOwner(this).lookup("service:chat-history");
  });

  test("visit dedupes consecutive identical routes", function (assert) {
    this.subject.visit({ name: "chat.starred-channels", params: {} });
    this.subject.visit({ name: "chat.channel", params: { channelId: "1" } });
    this.subject.visit({ name: "chat.channel", params: { channelId: "1" } });

    assert.strictEqual(
      this.subject.history.length,
      2,
      "the duplicate visit is skipped"
    );
    assert.strictEqual(
      this.subject.previousRoute.name,
      "chat.starred-channels",
      "previousRoute reflects the real prior step, not the duplicate"
    );
  });

  test("visit treats same name with different params as distinct", function (assert) {
    this.subject.visit({ name: "chat.channel", params: { channelId: "1" } });
    this.subject.visit({ name: "chat.channel", params: { channelId: "2" } });

    assert.strictEqual(this.subject.history.length, 2);
    assert.strictEqual(this.subject.previousRoute.params.channelId, "1");
    assert.strictEqual(this.subject.currentRoute.params.channelId, "2");
  });
});
