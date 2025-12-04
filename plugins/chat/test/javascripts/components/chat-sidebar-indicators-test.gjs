import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatSidebarIndicators from "discourse/plugins/chat/discourse/components/chat-sidebar-indicators";

module(
  "Discourse Chat | Component | chat-sidebar-indicators",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows indicator when unreadCount > 0", async function (assert) {
      const status = { unreadCount: 1 };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").exists();
    });

    test("shows indicator when unreadThreadsCount > 0", async function (assert) {
      const status = { unreadThreadsCount: 1 };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").exists();
    });

    test("shows indicator when mentionCount > 0", async function (assert) {
      const status = { mentionCount: 1 };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").exists();
      assert.dom(".sidebar-section-link-content-badge").hasClass("urgent");
    });

    test("shows indicator when watchedThreadsUnreadCount > 0", async function (assert) {
      const status = { watchedThreadsUnreadCount: 1 };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").exists();
      assert.dom(".sidebar-section-link-content-badge").hasClass("urgent");
    });

    test("does not show indicator when all counts are 0", async function (assert) {
      const status = {
        unreadCount: 0,
        unreadThreadsCount: 0,
        mentionCount: 0,
        watchedThreadsUnreadCount: 0,
      };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").doesNotExist();
    });

    test("shows urgent class for DM with unread messages", async function (assert) {
      const status = {
        unreadCount: 1,
        isDirectMessageChannel: true,
      };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").hasClass("urgent");
    });

    test("shows unread class for public channel with unread messages", async function (assert) {
      const status = {
        unreadCount: 1,
        isDirectMessageChannel: false,
      };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").hasClass("unread");
    });

    test("shows urgent class when watchedThreadsUnreadCount > 0 even without other unreads", async function (assert) {
      const status = {
        unreadCount: 0,
        unreadThreadsCount: 0,
        mentionCount: 0,
        watchedThreadsUnreadCount: 1,
        isDirectMessageChannel: false,
      };

      await render(
        <template><ChatSidebarIndicators @suffixArgs={{status}} /></template>
      );

      assert.dom(".sidebar-section-link-content-badge").exists();
      assert.dom(".sidebar-section-link-content-badge").hasClass("urgent");
    });
  }
);
