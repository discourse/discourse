import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
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
    hooks.afterEach(() => resetRichEditorExtensions());

    Object.entries({
      "regular poll": [
        "[poll]\n* Option 1\n* Option 2\n[/poll]\n\n",
        {},
        "[poll]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "multiple choice poll": [
        "[poll type=multiple min=1 max=2]\n* Option 1\n* Option 2\n* Option 3\n[/poll]",
        { type: "multiple", max: "2", min: "1" },
        "[poll type=multiple max=2 min=1]\n* Option 1\n* Option 2\n* Option 3\n\n[/poll]\n\n",
      ],
      "public poll": [
        "[poll public=true]\n* Option 1\n* Option 2\n[/poll]",
        { public: "true" },
        "[poll public=true]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "poll with name, results, close date, groups": [
        "[poll name=PollName chartType=pie results=always anonymous=true close=2021-01-01 groups=group1,group2]\n* Option 1\n* Option 2\n[/poll]",
        {
          results: "always",
          name: "PollName",
          charttype: "pie",
          close: "2021-01-01",
          groups: "group1,group2",
        },
        "[poll results=always name=PollName chartType=pie close=2021-01-01 groups=group1,group2]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
      "poll with bar chart type": [
        "[poll chartType=bar]\n* Option 1\n* Option 2\n[/poll]",
        { charttype: "bar" },
        "[poll chartType=bar]\n* Option 1\n* Option 2\n\n[/poll]\n\n",
      ],
    }).forEach(([name, [markdown, attrs, expectedMarkdown]]) => {
      test(name, async function (assert) {
        const [editor] = await setupRichEditor(assert, markdown);

        assert
          .dom(".composer-poll-node__content li")
          .exists(
            { count: attrs.type === "multiple" ? 3 : 2 },
            "renders the options"
          );
        assert
          .dom(".composer-poll-node__content li:first-child")
          .hasText("Option 1", "renders option text");
        assert
          .dom(".composer-poll-node__info .poll-info_counts")
          .hasText("0 voters", "renders the voter count");
        assert
          .dom(".composer-poll-node__edit")
          .hasText("Edit poll", "offers poll editing");
        for (const [attr, value] of Object.entries(attrs)) {
          assert
            .dom(".poll")
            .hasAttribute(`data-poll-${attr}`, value, `preserves ${attr}`);
        }
        assert.strictEqual(
          editor.value,
          expectedMarkdown,
          "serializes the poll without its edit control"
        );
      });
    });

    test("numeric polls preserve their range without serializing generated options", async function (assert) {
      const markdown = "[poll type=number max=10 min=0 step=2]\n[/poll]\n\n";
      const [editor] = await setupRichEditor(assert, markdown, {
        multiToggle: true,
      });

      assert
        .dom(".composer-poll-node__content li")
        .exists({ count: 6 }, "generates all six numeric options");
      assert
        .dom(".composer-poll-node__content li:first-child")
        .hasText("0", "includes zero as the lower bound");
      assert
        .dom(".composer-poll-node__content li:last-child")
        .hasText("10", "includes the upper bound");
      assert.strictEqual(
        editor.value,
        markdown,
        "preserves the range and step across editor toggles"
      );
    });

    test("numeric polls keep an authored title", async function (assert) {
      const markdown =
        "[poll type=number max=2 min=1]\n# How many?\n\n[/poll]\n\n";
      const [editor] = await setupRichEditor(assert, markdown);

      assert
        .dom(".composer-poll-node__content .poll-title")
        .hasText("How many?", "renders the title");
      assert
        .dom(".composer-poll-node__content li")
        .exists({ count: 2 }, "generates the options");
      assert.strictEqual(
        editor.value,
        markdown,
        "keeps the title and drops the generated options"
      );
    });

    test("the poll summary reflects the settings, not any votes", async function (assert) {
      await setupRichEditor(
        assert,
        "[poll type=multiple min=1 max=2 results=on_vote close=2050-01-01 dynamic=true]\n* Option 1\n* Option 2\n\n[/poll]\n\n"
      );

      assert
        .dom(".composer-poll-node__info .poll-info_counts")
        .hasText("0 voters", "shows no votes, because there are none yet");
      assert
        .dom(".composer-poll-node__info .multiple-help-text")
        .exists("explains how many options can be picked");
      assert
        .dom(".composer-poll-node__info .is-dynamic")
        .exists("mentions that options can change after posting");
      assert
        .dom(".composer-poll-node__info li[title]")
        .exists("says when the poll closes");
      assert
        .dom(".composer-poll-node__info .poll-info_instructions li")
        .exists(
          { count: 3 },
          "and leaves out what depends on who is reading the post"
        );
      assert
        .dom(".composer-poll-node__info .results-on-vote")
        .doesNotExist(
          "results visibility depends on the reader, not a setting"
        );
      assert
        .dom(".composer-poll-node__info .poll-info_counts-count")
        .exists({ count: 1 }, "claims no vote totals it cannot have");
    });

    test("a poll that has already closed does not say it will close", async function (assert) {
      await setupRichEditor(
        assert,
        "[poll close=2021-01-01]\n* Option 1\n* Option 2\n\n[/poll]\n\n"
      );

      assert
        .dom(".composer-poll-node__info .d-icon-lock")
        .exists("shows the close date as past");
      assert
        .dom(".composer-poll-node__info .d-icon-far-clock")
        .doesNotExist("rather than as a countdown");
    });

    test("a closed multiple choice poll claims no totals", async function (assert) {
      await setupRichEditor(
        assert,
        "[poll type=multiple min=1 max=2 status=closed]\n* Option 1\n* Option 2\n\n[/poll]\n\n"
      );

      assert
        .dom(".composer-poll-node__info .poll-info_counts-count")
        .exists({ count: 1 }, "no total votes block");
    });

    test("a title keeps markdown that would start a block", async function (assert) {
      const [editor] = await setupRichEditor(
        assert,
        "[poll]\n# - pick one\n* Option 1\n[/poll]"
      );

      assert
        .dom(".composer-poll-node__content .poll-title")
        .hasText("- pick one", "renders the title as written");
      assert.strictEqual(
        editor.value,
        "[poll]\n# - pick one\n\n* Option 1\n\n[/poll]\n\n",
        "and does not escape it on the way back"
      );
    });

    test("the editor says how another option is added", async function (assert) {
      await setupRichEditor(
        assert,
        "[poll]\n* Option 1\n* Option 2\n\n[/poll]\n\n"
      );

      assert
        .dom(".composer-poll-node__hint")
        .exists("explains that a line is an option");
    });

    test("a numeric poll does not, since its options are generated", async function (assert) {
      await setupRichEditor(
        assert,
        "[poll type=number max=2 min=1]\n[/poll]\n\n"
      );

      assert
        .dom(".composer-poll-node__hint")
        .doesNotExist("nothing to add by hand");
    });

    test("an untitled poll carries an empty title to type into", async function (assert) {
      const markdown = "[poll]\n* Option 1\n* Option 2\n\n[/poll]\n\n";
      const [editor] = await setupRichEditor(assert, markdown);

      assert
        .dom(".composer-poll-node__content > .poll-title")
        .exists("the title node is always present")
        .hasText("", "and is empty when the poll has no title");
      assert.strictEqual(
        editor.value,
        markdown,
        "an empty title is left out of the markdown"
      );
    });

    test("closed polls preserve status and option order", async function (assert) {
      const markdown =
        "[poll status=closed order=asc]\n* Option 1\n* Option 2\n\n[/poll]\n\n";
      const [editor] = await setupRichEditor(assert, markdown);

      assert
        .dom(".poll")
        .hasAttribute("data-poll-status", "closed", "keeps the poll closed");
      assert.strictEqual(
        editor.value,
        markdown,
        "preserves attributes not editable in the builder"
      );
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
