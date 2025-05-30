import { click } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - details extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      details: [
        [
          `[details="Summary"]This text will be hidden[/details]`,
          `<details><summary>Summary</summary><p>This text will be hidden</p></details>`,
          `[details="Summary"]\nThis text will be hidden\n\n[/details]\n\n`,
        ],
      ],
      "details with open attribute": [
        [
          `[details="Summary" open]This text will be hidden[/details]`,
          `<details open="true"><summary>Summary</summary><p>This text will be hidden</p></details>`,
          `[details="Summary" open]\nThis text will be hidden\n\n[/details]\n\n`,
        ],
      ],
      "details without summary": [
        [
          `[details]This text will be hidden[/details]`,
          `<details><summary></summary><p>This text will be hidden</p></details>`,
          `[details]\nThis text will be hidden\n\n[/details]\n\n`,
        ],
      ],
      "details without summary but with open attribute": [
        [
          `[details open]This text will be hidden[/details]`,
          `<details open="true"><summary></summary><p>This text will be hidden</p></details>`,
          `[details open]\nThis text will be hidden\n\n[/details]\n\n`,
        ],
      ],
    };

    Object.entries(testCases).forEach(([name, tests]) => {
      tests.forEach(([markdown, expectedHtml, expectedMarkdown]) => {
        test(name, async function (assert) {
          this.siteSettings.rich_editor = true;

          await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
        });
      });
    });

    test("opens and closes details on click", async function (assert) {
      this.siteSettings.rich_editor = true;
      const detailsMarkdown = `[details="Summary"]This text will be hidden[/details]`;
      await setupRichEditor(assert, detailsMarkdown);

      const detailsCss = ".d-editor-input details";
      const summaryCss = `${detailsCss} summary`;
      assert.dom(detailsCss).doesNotHaveAttribute("open");

      await click(summaryCss);
      assert.dom(detailsCss).hasAttribute("open");

      // click elsewhere first to avoid a double-click being detected
      await click(`${detailsCss} p`);
      await click(summaryCss);

      assert.dom(detailsCss).doesNotHaveAttribute("open");
    });
  }
);
