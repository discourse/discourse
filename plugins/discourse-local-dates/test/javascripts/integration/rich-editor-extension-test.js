import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - local-dates plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    test("local date", async function (assert) {
      this.siteSettings.rich_editor = true;
      const markdown = "[date=2021-01-01 time=12:00:00]";

      await testMarkdown(
        assert,
        markdown,
        (innerAssert) => {
          const span = document.querySelector(
            ".ProseMirror .discourse-local-date"
          );
          innerAssert.ok(span);
          innerAssert.strictEqual(span.dataset.date, "2021-01-01");
          innerAssert.strictEqual(span.dataset.time, "12:00:00");
          innerAssert.ok(span.textContent.length > 0);
        },
        markdown
      );
    });

    test("local date with timezone", async function (assert) {
      this.siteSettings.rich_editor = true;
      const markdown =
        '[date=2021-01-01 time=12:00:00 timezone="America/New_York"]';

      await testMarkdown(
        assert,
        markdown,
        (innerAssert) => {
          const span = document.querySelector(
            ".ProseMirror .discourse-local-date"
          );
          innerAssert.ok(span);
          innerAssert.strictEqual(span.dataset.date, "2021-01-01");
          innerAssert.strictEqual(span.dataset.time, "12:00:00");
          innerAssert.strictEqual(span.dataset.timezone, "America/New_York");
        },
        markdown
      );
    });

    test("local date range", async function (assert) {
      this.siteSettings.rich_editor = true;
      const markdown = "[date-range from=2021-01-01 to=2021-01-02]";

      await testMarkdown(
        assert,
        markdown,
        (innerAssert) => {
          const rangeSpan = document.querySelector(
            ".ProseMirror .discourse-local-date-range"
          );
          innerAssert.ok(rangeSpan);

          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');
          innerAssert.ok(fromSpan);
          innerAssert.ok(toSpan);
          innerAssert.strictEqual(fromSpan.dataset.date, "2021-01-01");
          innerAssert.strictEqual(toSpan.dataset.date, "2021-01-02");
        },
        markdown
      );
    });

    test("local date range with time", async function (assert) {
      this.siteSettings.rich_editor = true;
      const markdown =
        '[date-range from=2021-01-01T12:00:00 to=2021-01-02T13:00:00 timezone="America/New_York"]';

      await testMarkdown(
        assert,
        markdown,
        (innerAssert) => {
          const rangeSpan = document.querySelector(
            ".ProseMirror .discourse-local-date-range"
          );
          innerAssert.ok(rangeSpan);

          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');
          innerAssert.ok(fromSpan);
          innerAssert.ok(toSpan);
          innerAssert.strictEqual(fromSpan.dataset.date, "2021-01-01");
          innerAssert.strictEqual(fromSpan.dataset.time, "12:00:00");
          innerAssert.strictEqual(toSpan.dataset.date, "2021-01-02");
          innerAssert.strictEqual(toSpan.dataset.time, "13:00:00");
          innerAssert.strictEqual(
            fromSpan.dataset.timezone,
            "America/New_York"
          );
        },
        markdown
      );
    });
  }
);
