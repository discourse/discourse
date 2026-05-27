import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - local-dates plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.rich_editor = true;
    });

    function findDate() {
      return document.querySelector(".ProseMirror .discourse-local-date");
    }

    function findRange() {
      return document.querySelector(".ProseMirror .discourse-local-date-range");
    }

    test("local date", async function (assert) {
      const markdown = "[date=2021-01-01 time=12:00:00]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const span = findDate();
          assert.dom(span).exists();
          assert.strictEqual(span.dataset.date, "2021-01-01");
          assert.strictEqual(span.dataset.time, "12:00:00");
        },
        markdown
      );
    });

    test("local date without time", async function (assert) {
      const markdown = "[date=2021-01-01]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const span = findDate();
          assert.dom(span).exists();
          assert.strictEqual(span.dataset.date, "2021-01-01");
          assert.strictEqual(span.dataset.time, undefined);
        },
        markdown
      );
    });

    test("local date with timezone", async function (assert) {
      const markdown =
        "[date=2021-01-01 time=12:00:00 timezone=America/New_York]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.strictEqual(findDate().dataset.timezone, "America/New_York");
        },
        markdown
      );
    });

    test("local date with format", async function (assert) {
      const markdown =
        '[date=2021-01-01 time=12:00:00 format="YYYY-MM-DD HH:mm"]';

      await testMarkdown(
        assert,
        markdown,
        () => {
          const span = findDate();
          assert.strictEqual(span.dataset.format, "YYYY-MM-DD HH:mm");
          assert.true(span.textContent.includes("2021-01-01"));
        },
        markdown
      );
    });

    test("local date with recurring", async function (assert) {
      const markdown = "[date=2021-01-01 time=12:00:00 recurring=1.weeks]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.strictEqual(findDate().dataset.recurring, "1.weeks");
        },
        markdown
      );
    });

    test("local date with timezones", async function (assert) {
      const markdown =
        "[date=2021-01-01 time=12:00:00 timezones=Europe/Paris|Asia/Tokyo]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.strictEqual(
            findDate().dataset.timezones,
            "Europe/Paris|Asia/Tokyo"
          );
        },
        markdown
      );
    });

    test("local date with countdown", async function (assert) {
      const markdown = "[date=2099-01-01 time=12:00:00 countdown=true]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.strictEqual(findDate().dataset.countdown, "true");
        },
        markdown
      );
    });

    test("local date with displayedTimezone", async function (assert) {
      const markdown =
        "[date=2021-01-01 time=12:00:00 displayedTimezone=Europe/London]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.strictEqual(
            findDate().dataset.displayedTimezone,
            "Europe/London"
          );
        },
        markdown
      );
    });

    test("local date range", async function (assert) {
      const markdown = "[date-range from=2021-01-01 to=2021-01-02]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          assert.dom(rangeSpan).exists();

          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');
          assert.strictEqual(fromSpan.dataset.date, "2021-01-01");
          assert.strictEqual(toSpan.dataset.date, "2021-01-02");
        },
        markdown
      );
    });

    test("local date range with time", async function (assert) {
      const markdown =
        "[date-range from=2021-01-01T12:00:00 to=2021-01-02T13:00:00]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(fromSpan.dataset.date, "2021-01-01");
          assert.strictEqual(fromSpan.dataset.time, "12:00:00");
          assert.strictEqual(toSpan.dataset.date, "2021-01-02");
          assert.strictEqual(toSpan.dataset.time, "13:00:00");
        },
        markdown
      );
    });

    test("local date range with timezone", async function (assert) {
      const markdown =
        "[date-range from=2021-01-01 to=2021-01-02 timezone=America/New_York]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(fromSpan.dataset.timezone, "America/New_York");
          assert.strictEqual(toSpan.dataset.timezone, "America/New_York");
        },
        markdown
      );
    });

    test("local date range with format", async function (assert) {
      const markdown =
        "[date-range from=2021-01-01 to=2021-01-02 format=YYYY-MM-DD]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(fromSpan.dataset.format, "YYYY-MM-DD");
          assert.strictEqual(toSpan.dataset.format, "YYYY-MM-DD");
        },
        markdown
      );
    });

    test("local date range with timezones", async function (assert) {
      const markdown =
        "[date-range from=2021-01-01 to=2021-01-02 timezones=Europe/Paris|Asia/Tokyo]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(
            fromSpan.dataset.timezones,
            "Europe/Paris|Asia/Tokyo"
          );
          assert.strictEqual(
            toSpan.dataset.timezones,
            "Europe/Paris|Asia/Tokyo"
          );
        },
        markdown
      );
    });

    test("local date range with countdown", async function (assert) {
      const markdown =
        "[date-range from=2099-01-01 to=2099-01-02 countdown=true]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(fromSpan.dataset.countdown, "true");
          assert.strictEqual(toSpan.dataset.countdown, "true");
        },
        markdown
      );
    });

    test("local date range with displayedTimezone", async function (assert) {
      const markdown =
        "[date-range from=2021-01-01 to=2021-01-02 displayedTimezone=Europe/London]";

      await testMarkdown(
        assert,
        markdown,
        () => {
          const rangeSpan = findRange();
          const fromSpan = rangeSpan.querySelector('[data-range="from"]');
          const toSpan = rangeSpan.querySelector('[data-range="to"]');

          assert.strictEqual(
            fromSpan.dataset.displayedTimezone,
            "Europe/London"
          );
          assert.strictEqual(toSpan.dataset.displayedTimezone, "Europe/London");
        },
        markdown
      );
    });
  }
);
