import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { click, fillIn } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { createDirectMessageChannelDraft } from "discourse/plugins/chat/discourse/models/chat-channel";
import { Promise } from "rsvp";
import fabricators from "../helpers/fabricators";
import { module } from "qunit";

function mockChat(context, options = {}) {
  const mock = context.container.lookup("service:chat");
  mock.searchPossibleDirectMessageUsers = () => {
    return Promise.resolve({
      users: options.users || [{ username: "hawk" }, { username: "mark" }],
    });
  };
  mock.getDmChannelForUsernames = () => {
    return Promise.resolve({ chat_channel: fabricators.chatChannel() });
  };
  return mock;
}

module("Discourse Chat | Component | direct-message-creator", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("search", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await fillIn(".filter-usernames", "hawk");
      assert.ok(exists("li.user[data-username='hawk']"));
    },
  });

  componentTest("select/deselect", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      assert.notOk(exists(".selected-user"));

      await fillIn(".filter-usernames", "hawk");
      await click("li.user[data-username='hawk']");

      assert.ok(exists(".selected-user"));

      await click(".selected-user");

      assert.notOk(exists(".selected-user"));
    },
  });

  componentTest("no search results", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this, { users: [] }));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await fillIn(".filter-usernames", "bad cat");

      assert.ok(exists(".no-results"));
    },
  });

  componentTest("loads user on first load", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      assert.ok(exists("li.user[data-username='hawk']"));
      assert.ok(exists("li.user[data-username='mark']"));
    },
  });

  componentTest("do not load more users after selection", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await click("li.user[data-username='hawk']");

      assert.notOk(exists("li.user[data-username='mark']"));
    },
  });

  componentTest("apply is-focused to filter-area on focus input", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}<button class="test-blur">blur</button>`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await click(".filter-usernames");

      assert.ok(exists(".filter-area.is-focused"));

      await click(".test-blur");

      assert.notOk(exists(".filter-area.is-focused"));
    },
  });

  componentTest("state is reset on channel change", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      this.set("chat", mockChat(this));
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await fillIn(".filter-usernames", "hawk");

      assert.equal(query(".filter-usernames").value, "hawk");

      this.set("channel", fabricators.chatChannel());
      this.set("channel", createDirectMessageChannelDraft());

      assert.equal(query(".filter-usernames").value, "");
      assert.ok(exists(".filter-area.is-focused"));
      assert.ok(exists("li.user[data-username='hawk']"));
    },
  });

  componentTest("shows user status", {
    template: hbs`{{direct-message-creator channel=channel chat=chat}}`,

    beforeEach() {
      const userWithStatus = {
        username: "hawk",
        status: { emoji: "tooth", description: "off to dentist" },
      };
      const chat = mockChat(this, { users: [userWithStatus] });
      this.set("chat", chat);
      this.set("channel", createDirectMessageChannelDraft());
    },

    async test(assert) {
      await fillIn(".filter-usernames", "hawk");
      assert.ok(exists(".user-status-message"));
    },
  });
});
