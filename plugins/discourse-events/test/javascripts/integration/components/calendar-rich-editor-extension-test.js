import { module, test } from "qunit";
import toMarkdown from "discourse/lib/to-markdown";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | calendar RichEditorExtension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.discourse_events_enabled = true;
    });

    test("dynamic calendar", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar]\n[/calendar]",
        (a) => {
          a.dom(".composer-calendar-preview").exists();
          a.dom(".composer-calendar-preview__header").hasText("Calendar");
        },
        "[calendar]\n[/calendar]"
      );
    });

    test("calendar with attributes", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar type=static defaultView=listYear weekends=false fullDay=true]\n[/calendar]",
        (a) => {
          a.dom(".composer-calendar-preview__body").hasAttribute(
            "data-calendar-type",
            "static"
          );
          a.dom(".composer-calendar-preview__body").hasAttribute(
            "data-calendar-default-view",
            "listYear"
          );
          a.dom(".composer-calendar-preview__attrs").hasText(
            "type=static defaultView=listYear weekends=false fullDay=true"
          );
        },
        "[calendar type=static defaultView=listYear weekends=false fullDay=true]\n[/calendar]"
      );
    });

    test("static calendar with content", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar type=static]\nan event\n[/calendar]\n",
        (a) => {
          a.dom(".composer-calendar-preview__body p").hasText("an event");
        },
        "[calendar type=static]\nan event\n\n[/calendar]"
      );
    });

    // narrowing the content model to one paragraph made ProseMirror drop the
    // whole node, taking the author's events with it
    test("a body of several blocks is kept", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar type=static]\nOne\n\nTwo\n[/calendar]",
        (a) => {
          a.dom(".composer-calendar-preview__body p").exists({ count: 2 });
        },
        "[calendar type=static]\nOne\n\nTwo\n\n[/calendar]"
      );
    });

    test("a list in the body is kept", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar type=static]\n* a\n* b\n[/calendar]",
        (a) => {
          a.dom(".composer-calendar-preview__body li").exists({ count: 2 });
        },
        "[calendar type=static]\n* a\n* b\n\n[/calendar]"
      );
    });

    // hard breaks are the shape the cooked decorator reads events from
    test("hard breaks in the body are kept", async function (assert) {
      await testMarkdown(
        assert,
        "[calendar type=static]\nOne\nTwo\n[/calendar]",
        (a) => {
          a.dom(".composer-calendar-preview__body br").exists();
        },
        "[calendar type=static]\nOne\nTwo\n\n[/calendar]"
      );
    });

    // a calendar in a cooked post is replaced by the rendered widget, so its
    // markup must not be mistaken for a calendar the editor can round-trip
    test("pasting a rendered calendar does not build a calendar", async function (assert) {
      const rendered = `<div class="discourse-calendar-wrap"><div class="calendar" data-calendar-type="dynamic"><div class="fc-toolbar"><button>today</button></div></div></div>`;

      assert.false(
        (await toMarkdown(rendered)).includes("[calendar]"),
        "the widget markup is not turned into calendar bbcode"
      );
    });

    test("calendar with content around", async function (assert) {
      await testMarkdown(
        assert,
        "Hello\n\n[calendar]\n[/calendar]\n\nGoodbye",
        (a) => {
          a.dom(".composer-calendar-preview").exists();
          a.dom("p").exists({ count: 2 });
        },
        "Hello\n\n[calendar]\n[/calendar]\n\nGoodbye"
      );
    });
  }
);
