import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";
import { ALLOWED_ATTRIBUTES } from "discourse/plugins/poll/lib/discourse-markdown/poll";
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
        `<div class="poll" data-poll-results="always" data-poll-name="PollName" data-poll-charttype="pie" data-poll-close="2021-01-01" data-poll-groups="group1,group2"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
        "[poll results=always name=PollName chartType=pie close=2021-01-01 groups=group1,group2]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "poll with bar chart type": [
        "[poll chartType=bar]\n* Option 1\n* Option 2\n[/poll]",
        `<div class="poll" data-poll-charttype="bar"><ul data-tight="true"><li><p>Option 1</p></li><li><p>Option 2</p></li></ul>${voters}</div>`,
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

module("Unit | Lib | poll rich editor extension", function () {
  const { attrs, parseDOM } = richEditorExtension.nodeSpec.poll;

  test("carries every attribute the markdown rule allows", function (assert) {
    assert.deepEqual(
      Object.keys(attrs).sort(),
      [...ALLOWED_ATTRIBUTES].sort(),
      "the poll node keeps up with the markdown rule"
    );
  });

  test("reads the settings off cooked HTML", function (assert) {
    const container = document.createElement("div");
    container.innerHTML =
      '<div class="poll" data-poll-status="open" data-poll-name="poll" ' +
      'data-poll-results="always" data-poll-charttype="bar" ' +
      'data-poll-type="number" data-poll-order="asc" data-poll-step="2"></div>';

    const parsed = parseDOM[0].getAttrs(container.firstChild);

    assert.deepEqual(
      Object.fromEntries(
        Object.entries(parsed).filter(([, value]) => value !== null)
      ),
      {
        type: "number",
        results: "always",
        chartType: "bar",
        order: "asc",
        step: "2",
      },
      "keeps the settings and drops the ones cooking always supplies"
    );
  });
});
