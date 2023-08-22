import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Unit | Service | chat-drafts-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.subject = getOwner(this).lookup("service:chat-drafts-manager");
    });

    hooks.afterEach(function () {
      this.subject.reset();
    });

    test("storing and retrieving message", function (assert) {
      const message1 = fabricators.message();
      this.subject.add(message1);

      assert.strictEqual(
        this.subject.get({ channelId: message1.channel.id }),
        message1
      );

      const message2 = fabricators.message();
      this.subject.add(message2);

      assert.strictEqual(
        this.subject.get({ channelId: message2.channel.id }),
        message2
      );
    });

    test("stores only chat messages", function (assert) {
      assert.throws(function () {
        this.subject.add({ foo: "bar" });
      }, /instance of ChatMessage/);
    });

    test("#reset", function (assert) {
      this.subject.add(fabricators.message());

      assert.strictEqual(Object.keys(this.subject.drafts).length, 1);

      this.subject.reset();

      assert.strictEqual(Object.keys(this.subject.drafts).length, 0);
    });
  }
);
