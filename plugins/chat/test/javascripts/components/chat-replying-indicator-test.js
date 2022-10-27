import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import MockPresenceChannel from "../helpers/mock-presence-channel";
import { module } from "qunit";

module(
  "Discourse Chat | Component | chat-replying-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("not displayed when no one is replying", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        assert.notOk(exists(".chat-replying-indicator__text"));
      },
    });

    componentTest("displays indicator when user is replying", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        const sam = { id: 1, username: "sam" };
        this.set("presenceChannel.users", [sam]);

        assert.equal(
          query(".chat-replying-indicator__text").innerText,
          `${sam.username} is typing`
        );
      },
    });

    componentTest("displays indicator when 2 or 3 users are replying", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        const sam = { id: 1, username: "sam" };
        const mark = { id: 2, username: "mark" };
        this.set("presenceChannel.users", [sam, mark]);

        assert.equal(
          query(".chat-replying-indicator__text").innerText,
          `${sam.username} and ${mark.username} are typing`
        );
      },
    });

    componentTest("displays indicator when 3 users are replying", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        const sam = { id: 1, username: "sam" };
        const mark = { id: 2, username: "mark" };
        const joffrey = { id: 3, username: "joffrey" };
        this.set("presenceChannel.users", [sam, mark, joffrey]);

        assert.equal(
          query(".chat-replying-indicator__text").innerText,
          `${sam.username}, ${mark.username} and ${joffrey.username} are typing`
        );
      },
    });

    componentTest("displays indicator when more than 3 users are replying", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        const sam = { id: 1, username: "sam" };
        const mark = { id: 2, username: "mark" };
        const joffrey = { id: 3, username: "joffrey" };
        const taylor = { id: 4, username: "taylor" };
        this.set("presenceChannel.users", [sam, mark, joffrey, taylor]);

        assert.equal(
          query(".chat-replying-indicator__text").innerText,
          `${sam.username}, ${mark.username} and 2 others are typing`
        );
      },
    });

    componentTest("filters current user from list of repliers", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
          })
        );
      },

      async test(assert) {
        const sam = { id: 1, username: "sam" };
        this.set("presenceChannel.users", [sam, this.currentUser]);

        assert.equal(
          query(".chat-replying-indicator__text").innerText,
          `${sam.username} is typing`
        );
      },
    });

    componentTest("resets presence when channel is draft", {
      template: hbs`{{chat-replying-indicator presenceChannel=presenceChannel chatChannel=chatChannel}}`,

      async beforeEach() {
        this.set("chatChannel", fabricators.chatChannel());
        this.set(
          "presenceChannel",
          MockPresenceChannel.create({
            name: `/chat-reply/${this.chatChannel.id}`,
            subscribed: true,
          })
        );
      },

      async test(assert) {
        assert.ok(this.presenceChannel.subscribed);

        this.set("chatChannel", fabricators.chatChannel({ isDraft: true }));

        assert.notOk(this.presenceChannel.subscribed);
      },
    });
  }
);
