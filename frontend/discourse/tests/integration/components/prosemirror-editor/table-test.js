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
        `<div class="md-table"><table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table></div>`,
        `| Header 1 | Header 2 |\n|----|----|\n| Cell 1 | Cell 2 |\n\n`,
      ],
      "table with alignment": [
        `| Left | Center | Right |\n| :--- | :---: | ---: |\n| A | B | C |`,
        `<div class="md-table"><table><thead><tr><th style="text-align: left;">Left</th><th style="text-align: center;">Center</th><th style="text-align: right;">Right</th></tr></thead><tbody><tr><td style="text-align: left;">A</td><td style="text-align: center;">B</td><td style="text-align: right;">C</td></tr></tbody></table></div>`,
        `| Left | Center | Right |\n|:---|:---:|---:|\n| A | B | C |\n\n`,
      ],
      "table within quotes": [
        `> \n> | Header 1 | Header 2 |\n> | --- | --- |\n> | Cell 1 | Cell 2 |\n`,
        `<blockquote><div class="md-table"><table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table></div></blockquote>`,
        `> \n> | Header 1 | Header 2 |\n> |----|----|\n> | Cell 1 | Cell 2 |\n\n`,
      ],
      "table with br in cells": [
        `| Line1<br>Line2 | Cell 2 |\n| --- | --- |\n| Cell 3 | Cell 4 |`,
        `<div class="md-table"><table><thead><tr><th>Line1<br>Line2</th><th>Cell 2</th></tr></thead><tbody><tr><td>Cell 3</td><td>Cell 4</td></tr></tbody></table></div>`,
        `| Line1<br>Line2 | Cell 2 |\n|----|----|\n| Cell 3 | Cell 4 |\n\n`,
      ],
      "image dimensions in a cell": [
        `| Sign | Note |\n| --- | --- |\n| ![Rocket\\|500x500](https://example.com/r.png) | ok |`,
        (assert) => {
          assert.dom(".ProseMirror td img").hasAttribute("alt", "Rocket");
          assert.dom(".ProseMirror td img").hasAttribute("width", "500");
        },
        `| Sign | Note |\n|----|----|\n| ![Rocket\\|500x500](https://example.com/r.png) | ok |\n\n`,
      ],
      "attachment link in a cell": [
        `| File |\n| --- |\n| [notes.pdf\\|attachment](https://example.com/notes.pdf) |`,
        (assert) => {
          assert.dom(".ProseMirror td a").hasText("notes.pdf");
        },
        `| File |\n|----|\n| [notes.pdf\\|attachment](https://example.com/notes.pdf) |\n\n`,
      ],
      "literal pipe in cell text": [
        `| A |\n| --- |\n| x \\| y |`,
        `<div class="md-table"><table><thead><tr><th>A</th></tr></thead><tbody><tr><td>x | y</td></tr></tbody></table></div>`,
        `| A |\n|----|\n| x \\| y |\n\n`,
      ],
      "literal pipe in a header cell": [
        `| a \\| b |\n| --- |\n| c |`,
        `<div class="md-table"><table><thead><tr><th>a | b</th></tr></thead><tbody><tr><td>c</td></tr></tbody></table></div>`,
        `| a \\| b |\n|----|\n| c |\n\n`,
      ],
      "pipe inside an inline code span": [
        `| A |\n| --- |\n| \`x \\| y\` |`,
        `<div class="md-table"><table><thead><tr><th>A</th></tr></thead><tbody><tr><td><code>x | y</code></td></tr></tbody></table></div>`,
        `| A |\n|----|\n| \`x \\| y\` |\n\n`,
      ],
      // markdown-it percent-encodes link destinations on parse, in and out of
      // tables alike, so the destination holds no pipe left to escape
      "pipe inside a link destination": [
        `| A |\n| --- |\n| [t](https://example.com/a\\|b) |`,
        (assert) => {
          assert.dom(".ProseMirror td a").hasText("t");
        },
        `| A |\n|----|\n| [t](https://example.com/a%7Cb) |\n\n`,
      ],
      "escaped pipe in a table inside a quote": [
        `> \n> | A |\n> | --- |\n> | x \\| y |\n`,
        `<blockquote><div class="md-table"><table><thead><tr><th>A</th></tr></thead><tbody><tr><td>x | y</td></tr></tbody></table></div></blockquote>`,
        `> \n> | A |\n> |----|\n> | x \\| y |\n\n`,
      ],
      "literal backslash before a pipe": [
        `| A |\n| --- |\n| x \\\\\\| y |`,
        `<div class="md-table"><table><thead><tr><th>A</th></tr></thead><tbody><tr><td>x \\| y</td></tr></tbody></table></div>`,
        `| A |\n|----|\n| x \\\\\\| y |\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });

      test(`${name} - stable across repeated round-trips`, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown, true);
      });
    });
  }
);
