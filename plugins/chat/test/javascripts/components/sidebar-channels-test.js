import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import {
  setup as setupChatStub,
  teardown as teardownChatStub,
} from "../helpers/chat-stub";
import { module } from "qunit";

module("Discourse Chat | Component | sidebar-channels", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{sidebar-channels}}`,

    beforeEach() {
      setupChatStub(this);
    },

    afterEach() {
      teardownChatStub();
    },

    async test(assert) {
      assert.ok(exists("[data-chat-channel-id]"));
    },
  });

  componentTest("chat is on chat page", {
    template: hbs`{{sidebar-channels}}`,

    beforeEach() {
      setupChatStub(this, { fullScreenChatOpen: true });
    },

    afterEach() {
      teardownChatStub();
    },

    async test(assert) {
      assert.ok(exists("[data-chat-channel-id]"));
    },
  });

  componentTest("none of the conditions are fulfilled", {
    template: hbs`{{sidebar-channels}}`,

    beforeEach() {
      setupChatStub(this, { userCanChat: false, fullScreenChatOpen: false });
    },

    afterEach() {
      teardownChatStub();
    },

    async test(assert) {
      assert.notOk(exists("[data-chat-channel-id]"));
    },
  });

  componentTest("user cant chat", {
    template: hbs`{{sidebar-channels}}`,

    beforeEach() {
      setupChatStub(this, { userCanChat: false });
    },

    afterEach() {
      teardownChatStub();
    },

    async test(assert) {
      assert.notOk(exists("[data-chat-channel-id]"));
    },
  });
});
