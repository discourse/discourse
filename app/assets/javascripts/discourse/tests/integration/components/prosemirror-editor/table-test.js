import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - table extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic table": [
        "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |",
        `<table class="md-table"><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table>`,
        `| Header 1 | Header 2 |\n|----|----|\n| Cell 1 | Cell 2 |\n\n`,
      ],
      "table with alignment": [
        `| Left | Center | Right |\n| :--- | :---: | ---: |\n| A | B | C |`,
        `<table class="md-table"><thead><tr><th style="text-align: left">Left</th><th style="text-align: center">Center</th><th style="text-align: right">Right</th></tr></thead><tbody><tr><td style="text-align: left">A</td><td style="text-align: center">B</td><td style="text-align: right">C</td></tr></tbody></table>`,
        `| Left | Center | Right |\n|:---|:---:|---:|\n| A | B | C |\n\n`,
      ],
      "table within quotes": [
        `> \n> | Header 1 | Header 2 |\n> | --- | --- |\n> | Cell 1 | Cell 2 |\n`,
        `<blockquote><table class="md-table"><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table></blockquote>`,
        `> \n> | Header 1 | Header 2 |\n> |----|----|\n> | Cell 1 | Cell 2 |\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
