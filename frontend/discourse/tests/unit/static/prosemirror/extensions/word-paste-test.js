import { module, test } from "qunit";
import {
  transformWordLists,
  transformWordListsHtml,
} from "discourse/static/prosemirror/extensions/word-paste";

module("Unit | Static | ProseMirror | Extensions | word-paste", function () {
  function createDoc(html) {
    return new DOMParser().parseFromString(html, "text/html");
  }

  function wordListHtml(
    items,
    { startClass = "First", endClass = "Last" } = {}
  ) {
    return items
      .map((item, i) => {
        let cls = "MsoListParagraphCxSpMiddle";
        if (i === 0) {
          cls = `MsoListParagraphCxSp${startClass}`;
        }
        if (i === items.length - 1) {
          cls = `MsoListParagraphCxSp${endClass}`;
        }
        return `<p class="${cls}" style="mso-list:l0 level${item.level || 1} lfo1">
          <span style="mso-list:Ignore">${item.marker}</span>${item.text}
        </p>`;
      })
      .join("\n");
  }

  test("no-op when no Word list classes present", function (assert) {
    const html = "<p>Regular paragraph</p><ul><li>Normal list</li></ul>";
    assert.strictEqual(transformWordListsHtml(html), html);
  });

  test("converts unordered list", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Item 1" },
      { marker: "·", text: "Item 2" },
    ]);
    const doc = createDoc(transformWordListsHtml(html));

    assert.strictEqual(doc.querySelectorAll("ul").length, 1);
    assert.strictEqual(doc.querySelectorAll("li").length, 2);
    assert.strictEqual(
      doc.querySelectorAll("p.MsoListParagraphCxSpFirst").length,
      0
    );
  });

  test("detects ordered list from various marker formats", function (assert) {
    const markers = ["1.", "1)", "a.", "A)", "i.", "ii."];

    for (const marker of markers) {
      const html = wordListHtml([
        { marker, text: "First" },
        { marker: "2.", text: "Second" },
      ]);
      const doc = createDoc(transformWordListsHtml(html));
      assert.strictEqual(
        doc.querySelectorAll("ol").length,
        1,
        `marker "${marker}" creates ol`
      );
    }
  });

  test("sets start attribute for custom start number", function (assert) {
    const html = wordListHtml([
      { marker: "5.", text: "Fifth" },
      { marker: "6.", text: "Sixth" },
    ]);
    const doc = createDoc(transformWordListsHtml(html));
    assert.strictEqual(doc.querySelector("ol").getAttribute("start"), "5");
  });

  test("handles nested lists", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Level 1", level: 1 },
      { marker: "·", text: "Level 2", level: 2 },
      { marker: "·", text: "Level 3", level: 3 },
      { marker: "·", text: "Back to 1", level: 1 },
    ]);
    const doc = createDoc(transformWordListsHtml(html));

    assert.strictEqual(doc.querySelectorAll("ul").length, 3);
    assert.strictEqual(doc.querySelectorAll("li").length, 4);
  });

  test("handles IE conditional comments", function (assert) {
    const html = `
      <p class="MsoListParagraphCxSpFirst" style="mso-list:l0 level1 lfo1">
        <![if !supportLists]><span style="mso-list:Ignore">1.</span><![endif]>First
      </p>
      <p class="MsoListParagraphCxSpLast" style="mso-list:l0 level1 lfo1">
        <![if !supportLists]><span style="mso-list:Ignore">2.</span><![endif]>Second
      </p>
    `;
    const doc = createDoc(transformWordListsHtml(html));

    assert.strictEqual(doc.querySelectorAll("ol").length, 1);
    assert.false(doc.querySelector("li").textContent.includes("1."));
  });

  test("preserves inline formatting", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "<b>Bold</b>" },
      { marker: "·", text: "<i>Italic</i>" },
    ]);
    const doc = createDoc(transformWordListsHtml(html));

    assert.true(!!doc.querySelector("li b"));
    assert.true(!!doc.querySelector("li i"));
  });

  test("sets data-tight attribute", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Item 1" },
      { marker: "·", text: "Item 2" },
    ]);
    const doc = createDoc(transformWordListsHtml(html));
    assert.strictEqual(
      doc.querySelector("ul").getAttribute("data-tight"),
      "true"
    );
  });

  test("handles multiple separate lists with surrounding text", function (assert) {
    const html = `
      <p>Intro</p>
      ${wordListHtml([{ marker: "·", text: "Bullet" }])}
      <p>Middle</p>
      ${wordListHtml([{ marker: "1.", text: "Numbered" }])}
    `;
    const doc = createDoc(transformWordListsHtml(html));

    assert.strictEqual(doc.querySelectorAll("ul").length, 1);
    assert.strictEqual(doc.querySelectorAll("ol").length, 1);
  });

  test("transformWordLists modifies DOM in place", function (assert) {
    const doc = createDoc(wordListHtml([{ marker: "·", text: "Item" }]));

    transformWordLists(doc.body);

    assert.strictEqual(doc.querySelectorAll("ul").length, 1);
    assert.strictEqual(
      doc.querySelectorAll("p.MsoListParagraphCxSpFirst").length,
      0
    );
  });
});
