import { Plugin } from "prosemirror-state";
import { module, test } from "qunit";
import extension from "discourse/static/prosemirror/extensions/html-inline";

module(
  "Unit | Static | ProseMirror | Extensions | html-inline",
  function (hooks) {
    hooks.beforeEach(function () {
      this.transformPastedHTML = extension.plugins({
        pmState: { Plugin },
      }).props.transformPastedHTML;
    });

    test("strips lang from spans in pasted HTML", function (assert) {
      assert.strictEqual(
        this.transformPastedHTML(
          `<p><span class="sentence" lang="en">Text</span></p>`
        ),
        `<p><span class="sentence">Text</span></p>`
      );
    });

    test("strips lang however the attribute is spaced", function (assert) {
      assert.false(
        this.transformPastedHTML(`<span lang = "en">Text</span>`).includes(
          "lang"
        )
      );
    });

    test("keeps lang in a slice copied out of the editor", function (assert) {
      const html = `<p data-pm-slice="1 1 []"><span lang="ja">日本語</span></p>`;

      assert.strictEqual(this.transformPastedHTML(html), html);
    });

    test("leaves HTML without a lang attribute untouched", function (assert) {
      const html = `<p><span class="sentence">Text</span></p>`;

      assert.strictEqual(this.transformPastedHTML(html), html);
    });

    test("keeps lang on a ruby annotation", function (assert) {
      assert.true(
        this.transformPastedHTML(
          `<ruby lang="ja">漢<rt>かん</rt></ruby>`
        ).includes(`lang="ja"`)
      );
    });
  }
);
