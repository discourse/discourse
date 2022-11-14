import { set } from "@ember/object";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { module } from "qunit";

module(
  "Discourse Chat | Component | chat-composer placeholder",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("direct message to self shows Jot something down", {
      template: hbs`{{chat-composer chatChannel=chatChannel}}`,

      beforeEach() {
        set(this.currentUser, "id", 1);
        this.set(
          "chatChannel",
          ChatChannel.create({
            chatable_type: "DirectMessage",
            chatable: {
              users: [{ id: 1 }],
            },
          })
        );
      },

      async test(assert) {
        assert.equal(
          query(".chat-composer-input").placeholder,
          "Jot something down"
        );
      },
    });

    componentTest("direct message to multiple folks shows their names", {
      template: hbs`{{chat-composer chatChannel=chatChannel}}`,

      beforeEach() {
        this.set(
          "chatChannel",
          ChatChannel.create({
            chatable_type: "DirectMessage",
            chatable: {
              users: [
                { name: "Tomtom" },
                { name: "Steaky" },
                { username: "zorro" },
              ],
            },
          })
        );
      },

      async test(assert) {
        assert.equal(
          query(".chat-composer-input").placeholder,
          "Chat with Tomtom, Steaky, @zorro"
        );
      },
    });

    componentTest("message to channel shows send message to channel name", {
      template: hbs`{{chat-composer chatChannel=chatChannel}}`,

      beforeEach() {
        this.set(
          "chatChannel",
          ChatChannel.create({
            chatable_type: "Category",
            title: "just-cats",
          })
        );
      },

      async test(assert) {
        assert.equal(
          query(".chat-composer-input").placeholder,
          "Chat with #just-cats"
        );
      },
    });
  }
);
