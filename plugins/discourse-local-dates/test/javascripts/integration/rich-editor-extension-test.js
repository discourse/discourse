import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - local-dates plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "local date": [
        "[date=2021-01-01 time=12:00:00]",
        '<p><span class="discourse-local-date cooked-date" data-date="2021-01-01" data-time="12:00:00" contenteditable="false">January 1, 2021 12:00 PM</span></p>',
        "[date=2021-01-01 time=12:00:00]",
      ],
      "local date with timezone": [
        '[date=2021-01-01 time=12:00:00 timezone="America/New_York"]',
        '<p><span class="discourse-local-date cooked-date" data-date="2021-01-01" data-time="12:00:00" data-timezone="America/New_York" contenteditable="false">January 1, 2021 12:00 PM</span></p>',
        '[date=2021-01-01 time=12:00:00 timezone="America/New_York"]',
      ],
      "local date range": [
        "[date-range from=2021-01-01 to=2021-01-02]",
        '<p><span class="discourse-local-date-range" contenteditable="false"><span class="discourse-local-date cooked-date" data-range="from" data-date="2021-01-01">January 1, 2021</span> → <span class="discourse-local-date cooked-date" data-range="to" data-date="2021-01-02">January 2, 2021</span></span></p>',
        "[date-range from=2021-01-01 to=2021-01-02]",
      ],
      "local date range with time": [
        '[date-range from=2021-01-01T12:00:00 to=2021-01-02T13:00:00 timezone="America/New_York"]',
        '<p><span class="discourse-local-date-range" contenteditable="false"><span class="discourse-local-date cooked-date" data-range="from" data-date="2021-01-01" data-time="12:00:00" data-timezone="America/New_York">January 1, 2021 12:00 PM</span> → <span class="discourse-local-date cooked-date" data-range="to" data-date="2021-01-02" data-time="13:00:00" data-timezone="America/New_York">January 2, 2021 1:00 PM</span></span></p>',
        '[date-range from=2021-01-01T12:00:00 to=2021-01-02T13:00:00 timezone="America/New_York"]',
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
