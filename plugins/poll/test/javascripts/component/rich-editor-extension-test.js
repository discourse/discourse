import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/poll/lib/rich-editor-extension";

module(
  "Integration | Component | prosemirror-editor - poll plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      await resetRichEditorExtensions();
      registerRichEditorExtension(richEditorExtension);
    });

    const voters =
      '<div class="poll-info" contenteditable="false">0 voters</div>';

    Object.entries({
      "regular poll": [
        "[poll]\n* Option 1\n* Option 2\n[/poll]\n\n",
        `<div class="poll"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "multiple choice poll": [
        "[poll type=multiple min=1 max=2]\n* Option 1\n* Option 2\n* Option 3\n[/poll]",
        `<div class="poll" data-poll-type="multiple" data-poll-max="2" data-poll-min="1"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li><li><p>Option 3</p></li></ul>${voters}</div>`,
        "[poll type=multiple max=2 min=1]\n* Option 1\n* Option 2\n* Option 3\n\n[/poll]\n\n",
      ],
      "public poll": [
        "[poll public=true]\n* Option 1\n* Option 2\n[/poll]",
        `<div class="poll" data-poll-public="true"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll public=true]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "poll with name, results, close date, groups": [
        "[poll name=PollName chartType=pie results=always anonymous=true close=2021-01-01 groups=group1,group2]\n* Option 1\n* Option 2\n[/poll]",
        `<div class="poll" data-poll-results="always" data-poll-name="PollName" data-poll-chart-type="pie" data-poll-close="2021-01-01" data-poll-groups="group1,group2"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll results=always name=PollName chartType=pie close=2021-01-01 groups=group1,group2]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "poll with bar chart type": [
        "[poll chartType=bar]\n* Option 1\n* Option 2\n[/poll]",
        `<div class="poll" data-poll-chart-type="bar"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll chartType=bar]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "closed poll with a set option order": [
        "[poll status=closed order=asc]\n* Option 1\n* Option 2\n[/poll]",
        `<div class="poll" data-poll-status="closed" data-poll-order="asc"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll status=closed order=asc]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "number poll": [
        "[poll type=number min=0 max=4 step=2]\n[/poll]",
        `<div class="poll" data-poll-type="number" data-poll-max="4" data-poll-min="0" data-poll-step="2"><ul data-tight="true"><li><p>0</p></li><li><p>2</p></li><li><p>4</p></li></ul>${voters}</div>`,
        "[poll type=number max=4 min=0 step=2]\n[/poll]\n\n",
      ],
      "number poll with a title": [
        "[poll type=number min=1 max=2]\n# How many?\n[/poll]",
        `<div class="poll" data-poll-type="number" data-poll-max="2" data-poll-min="1"><h1>How many?</h1><ul data-tight="true"><li><p>1</p></li><li><p>2</p></li></ul>${voters}</div>`,
        "[poll type=number max=2 min=1]\n# How many?\n\n[/poll]\n\n",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
