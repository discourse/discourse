import { module, test } from "qunit";
import {
  stripWordLangAttributes,
  stripWordReviewMarkup,
  transformWordHtml,
  transformWordLists,
  transformWordQuotes,
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
    assert.strictEqual(transformWordHtml(html), html);
  });

  test("converts unordered list", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Item 1" },
      { marker: "·", text: "Item 2" },
    ]);
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("ul").length, 1);
    assert.strictEqual(doc.querySelectorAll("li").length, 2);
    assert.strictEqual(
      doc.querySelectorAll("p.MsoListParagraphCxSpFirst").length,
      0
    );
  });

  test("detects ordered list from various marker formats", function (assert) {
    const markers = [
      "1.",
      "1)",
      "a.",
      "A)",
      "i.",
      "ii.",
      "L.",
      "C)",
      "D.",
      "M)",
    ];

    for (const marker of markers) {
      const html = wordListHtml([
        { marker, text: "First" },
        { marker: "2.", text: "Second" },
      ]);
      const doc = createDoc(transformWordHtml(html));
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
    const doc = createDoc(transformWordHtml(html));
    assert.strictEqual(doc.querySelector("ol").getAttribute("start"), "5");
  });

  test("handles nested lists", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Level 1", level: 1 },
      { marker: "·", text: "Level 2", level: 2 },
      { marker: "·", text: "Level 3", level: 3 },
      { marker: "·", text: "Back to 1", level: 1 },
    ]);
    const doc = createDoc(transformWordHtml(html));

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
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("ol").length, 1);
    assert.false(doc.querySelector("li").textContent.includes("1."));
  });

  test("preserves inline formatting", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "<b>Bold</b>" },
      { marker: "·", text: "<i>Italic</i>" },
    ]);
    const doc = createDoc(transformWordHtml(html));

    assert.true(!!doc.querySelector("li b"));
    assert.true(!!doc.querySelector("li i"));
  });

  test("sets data-tight attribute", function (assert) {
    const html = wordListHtml([
      { marker: "·", text: "Item 1" },
      { marker: "·", text: "Item 2" },
    ]);
    const doc = createDoc(transformWordHtml(html));
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
    const doc = createDoc(transformWordHtml(html));

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

  test("converts Word Quote style to blockquote", function (assert) {
    const html = `<p class=MsoQuote style='margin-left:.5in'>Quoted line</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 1);
    assert.strictEqual(doc.querySelectorAll("p.MsoQuote").length, 0);
    assert.true(
      doc.querySelector("blockquote").textContent.includes("Quoted line")
    );
  });

  test("converts Word Intense Quote style to blockquote", function (assert) {
    const html = `<p class=MsoIntenseQuote>Intense line</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 1);
    assert.strictEqual(doc.querySelectorAll("p.MsoIntenseQuote").length, 0);
  });

  test("merges consecutive quote paragraphs into one blockquote", function (assert) {
    const html = `
      <p class=MsoQuote>First line</p>
      <p class=MsoQuote>Second line</p>
      <p>Not a quote</p>
      <p class=MsoQuote>Separate quote</p>
    `;
    const doc = createDoc(transformWordHtml(html));

    const blockquotes = doc.querySelectorAll("blockquote");
    assert.strictEqual(blockquotes.length, 2);
    assert.strictEqual(blockquotes[0].querySelectorAll("p").length, 2);
    assert.strictEqual(blockquotes[1].querySelectorAll("p").length, 1);
  });

  test("preserves inline formatting in quotes", function (assert) {
    const html = `<p class=MsoQuote>Has <b>bold</b> text</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.true(!!doc.querySelector("blockquote b"));
  });

  test("transformWordQuotes modifies DOM in place", function (assert) {
    const doc = createDoc(`<p class=MsoQuote>Quoted</p>`);

    transformWordQuotes(doc.body);

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 1);
    assert.strictEqual(doc.querySelectorAll("p.MsoQuote").length, 0);
  });

  test("converts Word Block Text style to blockquote", function (assert) {
    const html = `<p class=MsoBlockText>Block text line</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 1);
    assert.strictEqual(doc.querySelectorAll("p.MsoBlockText").length, 0);
  });

  test("converts Word for the web Quote style to blockquote regardless of locale", function (assert) {
    // PT-BR document: visible text is localized but the style id stays English
    const html = `
      <div class="OutlineElement"><p class="Paragraph" lang="PT-BR"><span
        class="TextRun"><span class="NormalTextRun"
        data-ccp-parastyle="Quote">Citação</span></span></p></div>
      <div class="OutlineElement"><p class="Paragraph" lang="PT-BR"><span
        class="TextRun"><span class="NormalTextRun">Regular text</span></span></p></div>
    `;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 1);
    assert.true(
      doc.querySelector("blockquote").textContent.includes("Citação")
    );
    assert.false(
      doc.querySelector("blockquote").textContent.includes("Regular text")
    );
  });

  test("does not convert non-quote Word for the web styles", function (assert) {
    const html = `<div class="OutlineElement"><p class="Paragraph"><span
      class="NormalTextRun" data-ccp-parastyle="Texto de Dica">Tip</span></p></div>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("blockquote").length, 0);
  });

  test("strips Word comment references and comment body", function (assert) {
    const html = `<p class=MsoNormal>Significant accounts
      <a class=msocomanchor href="#_msocom_1">[J1]</a>
      and assertions.</p>
      <div style='mso-element:comment-list'>
        <div style='mso-element:comment'>
          <p class=MsoCommentText>Consider removing.</p>
        </div>
      </div>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("a.msocomanchor").length, 0);
    assert.strictEqual(
      doc.querySelectorAll("[style*='mso-element:comment-list']").length,
      0
    );
    assert.false(doc.body.textContent.includes("[J1]"));
    assert.false(doc.body.textContent.includes("Consider removing."));
    assert.true(doc.body.textContent.includes("Significant accounts"));
  });

  test("strips Word tracked deletions but keeps surrounding text", function (assert) {
    const html = `<p class=MsoNormal>Keep <del>deleted text</del>this.</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("del").length, 0);
    assert.false(doc.body.textContent.includes("deleted text"));
    assert.true(doc.body.textContent.includes("Keep"));
  });

  test("does not strip <del> from non-Word HTML", function (assert) {
    const html = `<p>Keep <del>struck</del> text</p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("del").length, 1);
  });

  test("stripWordReviewMarkup modifies DOM in place", function (assert) {
    const doc = createDoc(
      `<p>Text <a class=msocomanchor href="#_msocom_1">[1]</a></p>`
    );

    stripWordReviewMarkup(doc.body);

    assert.strictEqual(doc.querySelectorAll("a.msocomanchor").length, 0);
  });

  test("strips the document-language lang attribute from Word for the web runs", function (assert) {
    const html = `<div class="OutlineElement"><p class="Paragraph"><span
      class="TextRun" lang="EN-GB"><span class="NormalTextRun"
      lang="EN-GB">Hello</span></span></p></div>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("[lang]").length, 0);
    assert.true(doc.body.textContent.includes("Hello"));
  });

  test("does not strip lang from non-Word HTML", function (assert) {
    const html = `<p><span lang="ja">日本語</span></p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("span[lang='ja']").length, 1);
  });

  test("does not treat a generic TextRun class as Word (no content loss)", function (assert) {
    const html = `<p class="TextRun">Keep <del>this</del> <span lang="fr">bonjour</span></p>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("del").length, 1);
    assert.strictEqual(doc.querySelectorAll("span[lang='fr']").length, 1);
  });

  test("keeps an intentional lang span inside a Word paste", function (assert) {
    const html = `<div class="OutlineElement"><p class="Paragraph">
      <span class="TextRun" lang="EN-GB">Note </span>
      <span lang="fr">bonjour</span>
    </p></div>`;
    const doc = createDoc(transformWordHtml(html));

    assert.strictEqual(doc.querySelectorAll("span.TextRun[lang]").length, 0);
    assert.strictEqual(doc.querySelectorAll("span[lang='fr']").length, 1);
  });

  test("stripWordLangAttributes modifies DOM in place", function (assert) {
    const doc = createDoc(
      `<p><span class="TextRun" lang="EN-GB">Text</span></p>`
    );

    stripWordLangAttributes(doc.body);

    assert.strictEqual(doc.querySelectorAll("[lang]").length, 0);
    assert.true(doc.body.textContent.includes("Text"));
  });
});
