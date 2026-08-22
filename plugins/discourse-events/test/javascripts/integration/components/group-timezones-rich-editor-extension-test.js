import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | group timezones RichEditorExtension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.discourse_events_enabled = true;
    });

    test("group timezones", async function (assert) {
      await testMarkdown(
        assert,
        "[timezones group=admins]\n[/timezones]",
        (a) => {
          a.dom(".composer-group-timezones-preview").hasAttribute(
            "data-group",
            "admins"
          );
          a.dom(".composer-group-timezones-preview").hasText(
            "Group timezones: admins"
          );
        },
        "[timezones group=admins]\n[/timezones]"
      );
    });

    test("a non-default size is kept", async function (assert) {
      await testMarkdown(
        assert,
        "[timezones group=admins size=large]\n[/timezones]",
        (a) => {
          a.dom(".composer-group-timezones-preview").hasAttribute(
            "data-size",
            "large"
          );
        },
        "[timezones group=admins size=large]\n[/timezones]"
      );
    });

    // the widget is appended when cooked, so authored content is kept
    test("content between the tags survives", async function (assert) {
      await testMarkdown(
        assert,
        "[timezones group=admins]\nsome note\n[/timezones]",
        (a) => {
          a.dom(".composer-group-timezones-preview__body p").hasText(
            "some note"
          );
        },
        "[timezones group=admins]\nsome note\n\n[/timezones]"
      );
    });

    test("a group is required to convert while typing", async function (assert) {
      await testMarkdown(
        assert,
        "[timezones]\n[/timezones]",
        (a) => {
          a.dom(".composer-group-timezones-preview").exists();
        },
        "[timezones]\n[/timezones]"
      );
    });

    test("alongside a calendar", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar]\n[/calendar]\n\n[timezones group=admins]\n[/timezones]",
        (a) => {
          a.dom(".composer-calendar-preview").exists();
          a.dom(".composer-group-timezones-preview").exists();
        },
        "[calendar]\n[/calendar]\n\n[timezones group=admins]\n[/timezones]"
      );
    });
  }
);
