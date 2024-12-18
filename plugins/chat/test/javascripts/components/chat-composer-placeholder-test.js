import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

module(
  "Discourse Chat | Component | chat-composer placeholder",
  function (hooks) {
    setupRenderingTest(hooks);

    test("direct message to self shows Jot something down", async function (assert) {
      pretender.get("/chat/emojis.json", () => [200, [], {}]);

      this.currentUser.set("id", 1);
      this.channel = ChatChannel.create({
        chatable_type: "DirectMessage",
        chatable: {
          users: [{ id: 1 }],
        },
      });

      await render(hbs`<Chat::Composer::Channel @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-composer__input").placeholder,
        "Jot something down"
      );
    });

    test("direct message to multiple folks shows their names when not a group", async function (assert) {
      pretender.get("/chat/emojis.json", () => [200, [], {}]);

      this.channel = ChatChannel.create({
        chatable_type: "DirectMessage",
        chatable: {
          group: false,
          users: [
            { name: "Tomtom" },
            { name: "Steaky" },
            { username: "zorro" },
          ],
        },
      });

      await render(hbs`<Chat::Composer::Channel @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-composer__input").placeholder,
        "Chat with Tomtom, Steaky, @zorro"
      );
    });

    test("direct message to group shows Chat in group", async function (assert) {
      pretender.get("/chat/emojis.json", () => [200, [], {}]);

      this.channel = ChatChannel.create({
        chatable_type: "DirectMessage",
        title: "Meetup Chat",
        chatable: {
          group: true,
          users: [
            { username: "user1" },
            { username: "user2" },
            { username: "user3" },
          ],
        },
      });

      await render(hbs`<Chat::Composer::Channel @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-composer__input").placeholder,
        i18n("chat.placeholder_group")
      );
    });

    test("message to channel shows send message to channel name", async function (assert) {
      pretender.get("/chat/emojis.json", () => [200, [], {}]);

      this.channel = ChatChannel.create({
        chatable_type: "Category",
        title: "just-cats",
      });

      await render(hbs`<Chat::Composer::Channel @channel={{this.channel}} />`);

      assert.strictEqual(
        query(".chat-composer__input").placeholder,
        "Chat in #just-cats"
      );
    });
  }
);
