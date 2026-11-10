import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import ChatMessageSeparator from "discourse/plugins/chat/discourse/components/chat-message-separator";

module("Component | ChatMessageSeparator", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    stubIntersectionObserver();
    moment.tz.setDefault("UTC");
    this.currentUser.user_option.timezone = "Europe/Madrid";
  });

  hooks.afterEach(function () {
    moment.tz.setDefault();
  });

  test("separates messages on different days in the user's timezone", async function (assert) {
    this.message = {
      id: 2,
      createdAt: new Date("2026-09-27T22:30:00Z"),
      previousMessage: {
        createdAt: new Date("2026-09-27T21:30:00Z"),
      },
      channel: { newestMessage: null },
    };

    await render(
      <template><ChatMessageSeparator @message={{this.message}} /></template>
    );

    assert.dom(".chat-message-separator-date").exists();
  });
});
