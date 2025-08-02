import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Unit | Service | chat-drafts-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.subject = getOwner(this).lookup("service:chat-drafts-manager");
    });

    test("storing and retrieving message", async function (assert) {
      const message1 = new ChatFabricators(getOwner(this)).message();

      await this.subject.add(message1, message1.channel.id);

      assert.strictEqual(this.subject.get(message1.channel.id), message1);

      const message2 = new ChatFabricators(getOwner(this)).message();

      await this.subject.add(message2, message2.channel.id);

      assert.strictEqual(this.subject.get(message2.channel.id), message2);
    });

    test("#reset", async function (assert) {
      const message = new ChatFabricators(getOwner(this)).message();

      await this.subject.add(message, message.channel.id);

      assert.strictEqual(Object.keys(this.subject.drafts).length, 1);

      this.subject.reset();

      assert.strictEqual(Object.keys(this.subject.drafts).length, 0);
    });
  }
);
