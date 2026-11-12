/* eslint-disable qunit/no-conditional-assertions */
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import {
  caretRowCol,
  clipboardCopyAsync,
  defaultHomepage,
  emailValid,
  escapeExpression,
  extractDomainFromUrl,
  fillMissingDates,
  findTableRegex,
  inCodeBlock,
  initializeDefaultHomepage,
  mergeSortedLists,
  selectedHTML,
  selectedText,
  setCaretPosition,
  setDefaultHomepage,
  slugify,
  toAsciiPrintable,
  translateModKey,
  unicodeSlugify,
} from "discourse/lib/utilities";
import Site from "discourse/models/site";
import {
  chromeTest,
  fixture,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Unit | Utilities", function (hooks) {
  setupTest(hooks);

  test("escapeExpression", function (assert) {
    assert.strictEqual(
      escapeExpression(">"),
      "&gt;",
      "escapes unsafe characters"
    );

    assert.strictEqual(
      escapeExpression(undefined),
      "",
      "returns a falsy string when given a falsy value"
    );
  });

  test("emailValid", function (assert) {
    assert.true(
      emailValid("Bob@example.com"),
      "allows upper case in the first part of emails"
    );
    assert.true(
      emailValid("bob@EXAMPLE.com"),
      "allows upper case in the email domain"
    );
  });

  test("extractDomainFromUrl", function (assert) {
    assert.strictEqual(
      extractDomainFromUrl("http://meta.discourse.org:443/random"),
      "meta.discourse.org",
      "extract domain name from url"
    );
    assert.strictEqual(
      extractDomainFromUrl("meta.discourse.org:443/random"),
      "meta.discourse.org",
      "extract domain regardless of scheme presence"
    );
    assert.strictEqual(
      extractDomainFromUrl("http://192.168.0.1:443/random"),
      "192.168.0.1",
      "works for IP address"
    );
    assert.strictEqual(
      extractDomainFromUrl("http://localhost:443/random"),
      "localhost",
      "works for localhost"
    );
  });

  test("defaultHomepage via meta tag", function (assert) {
    let meta = document.createElement("meta");
    meta.name = "discourse_current_homepage";
    meta.content = "hot";
    document.body.appendChild(meta);

    const siteSettings = getOwner(this).lookup("service:site-settings");
    initializeDefaultHomepage(siteSettings);

    assert.strictEqual(
      defaultHomepage(),
      "hot",
      "default homepage is pulled from <meta name=discourse_current_homepage>"
    );
    document.body.removeChild(meta);
  });

  test("defaultHomepage via site settings", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.top_menu = "top|latest|hot";
    initializeDefaultHomepage(siteSettings);

    assert.strictEqual(
      defaultHomepage(),
      "top",
      "default homepage is the first item in the top_menu site setting"
    );
  });

  test("defaultHomepage prefers the default_homepage site setting", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.top_menu = "top|latest|hot";
    siteSettings.default_homepage = "hot";
    initializeDefaultHomepage(siteSettings);

    assert.strictEqual(
      defaultHomepage(),
      "hot",
      "default homepage is pulled from the default_homepage site setting"
    );
  });

  test("defaultHomepage ignores a default_homepage value that is no longer an eligible choice", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.top_menu = "top|latest|hot";
    siteSettings.default_homepage = "votes";

    const site = Site.current();
    const originalChoices = site.homepage_choices;

    try {
      site.set("homepage_choices", ["latest", "top", "hot"]);
      initializeDefaultHomepage(siteSettings);
      assert.strictEqual(
        defaultHomepage(),
        "top",
        "an ineligible value falls back to the first top_menu item"
      );

      site.set("homepage_choices", ["latest", "top", "hot", "votes"]);
      initializeDefaultHomepage(siteSettings);
      assert.strictEqual(
        defaultHomepage(),
        "votes",
        "an eligible value is used"
      );
    } finally {
      site.set("homepage_choices", originalChoices);
    }
  });

  test("setDefaultHomepage", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    initializeDefaultHomepage(siteSettings);

    assert.strictEqual(defaultHomepage(), "latest");

    setDefaultHomepage("top");
    assert.strictEqual(defaultHomepage(), "top");
  });

  test("caretRowCol", function (assert) {
    let textarea = document.createElement("textarea");
    const content = document.createTextNode("01234\n56789\n012345");
    textarea.appendChild(content);
    document.body.appendChild(textarea);

    const assertResult = (setCaretPos, expectedRowNum, expectedColNum) => {
      setCaretPosition(textarea, setCaretPos);

      const result = caretRowCol(textarea);
      assert.strictEqual(
        result.rowNum,
        expectedRowNum,
        "returns the right row of the caret"
      );
      assert.strictEqual(
        result.colNum,
        expectedColNum,
        "returns the right col of the caret"
      );
    };

    assertResult(0, 1, 0);
    assertResult(5, 1, 5);
    assertResult(6, 2, 0);
    assertResult(11, 2, 5);
    assertResult(14, 3, 2);

    document.body.removeChild(textarea);
  });

  test("toAsciiPrintable", function (assert) {
    const accentedString = "Créme_Brûlée!";
    const unicodeString = "談話";

    assert.strictEqual(
      toAsciiPrintable(accentedString, "discourse"),
      "Creme_Brulee!",
      "it replaces accented characters with the appropriate ASCII equivalent"
    );

    assert.strictEqual(
      toAsciiPrintable(unicodeString, "discourse"),
      "discourse",
      "it uses the fallback string when unable to convert"
    );

    assert.strictEqual(
      typeof toAsciiPrintable(unicodeString),
      "undefined",
      "it returns undefined when unable to convert and no fallback is provided"
    );
  });

  test("slugify", function (assert) {
    const asciiString = "--- 0__( Some-cool Discourse Site! )__0 --- ";
    const accentedString = "Créme_Brûlée!";
    const unicodeString = "談話";

    assert.strictEqual(
      slugify(asciiString),
      "0-some-cool-discourse-site-0",
      "it properly slugifies an ASCII string"
    );

    assert.strictEqual(
      slugify(accentedString),
      "crme-brle",
      "it removes accented characters"
    );

    assert.strictEqual(
      slugify(unicodeString),
      "",
      "it removes unicode characters"
    );
  });

  test("unicodeSlugify", function (assert) {
    const asciiString = "--- 0__( Some--cool Discourse Site! )__0 --- ";
    const accentedString = "Créme_Brûlée!";
    const unicodeString = "談話";
    const unicodeStringWithEmojis = "⌘😁 談話";

    assert.strictEqual(
      unicodeSlugify(asciiString),
      "0-some-cool-discourse-site-0",
      "it properly slugifies an ASCII string"
    );

    assert.strictEqual(
      unicodeSlugify(accentedString),
      "creme-brulee",
      "it removes diacritics"
    );

    assert.strictEqual(
      unicodeSlugify(unicodeString),
      "談話",
      "it keeps unicode letters"
    );

    assert.strictEqual(
      unicodeSlugify(unicodeStringWithEmojis),
      "談話",
      "it removes emojis and symbols"
    );
  });

  test("fillMissingDates", function (assert) {
    const startDate = "2017-11-12"; // YYYY-MM-DD
    const endDate = "2017-12-12"; // YYYY-MM-DD
    const data =
      '[{"x":"2017-11-12","y":3},{"x":"2017-11-27","y":2},{"x":"2017-12-06","y":9},{"x":"2017-12-11","y":2}]';

    assert.strictEqual(
      fillMissingDates(JSON.parse(data), startDate, endDate).length,
      31,
      "it returns a JSON array with 31 dates"
    );
  });

  test("inCodeBlock", async function (assert) {
    const text =
      "000\n\n```\n111\n```\n\n000\n\n`111 111`\n\n000\n\n[code]\n111\n[/code]\n\n    111\n\t111\n\n000`000";

    for (let i = 0; i < text.length; ++i) {
      if (text[i] === "0" || text[i] === "1") {
        let inCode = await inCodeBlock(text, i);
        assert.strictEqual(inCode, text[i] === "1");
      }
    }
  });

  test("mergeSortedLists", function (assert) {
    const comparator = (a, b) => b > a;
    assert.deepEqual(
      mergeSortedLists([], [1, 2, 3], comparator),
      [1, 2, 3],
      "it doesn't error when the first list is blank"
    );
    assert.deepEqual(
      mergeSortedLists([3, 2, 1], [], comparator),
      [3, 2, 1],
      "it doesn't error when the second list is blank"
    );
    assert.deepEqual(
      mergeSortedLists([], [], comparator),
      [],
      "it doesn't error when the both lists are blank"
    );
    assert.deepEqual(
      mergeSortedLists([5, 4, 0, -1], [1], comparator),
      [5, 4, 1, 0, -1],
      "it correctly merges lists when one list has 1 item only"
    );
    assert.deepEqual(
      mergeSortedLists([2], [1], comparator),
      [2, 1],
      "it correctly merges lists when both lists has 1 item each"
    );
    assert.deepEqual(
      mergeSortedLists([1], [1], comparator),
      [1, 1],
      "it correctly merges lists when both lists has 1 item and their items are identical"
    );
    assert.deepEqual(
      mergeSortedLists([5, 4, 3, 2, 1], [6, 2, 1], comparator),
      [6, 5, 4, 3, 2, 2, 1, 1],
      "it correctly merges lists that share common items"
    );
  });
});

module("Unit | Utilities | selectedHTML", function (hooks) {
  setupTest(hooks);

  test("drops a trailing empty block left by a triple-click selection", function (assert) {
    const container = document.createElement("div");
    container.classList.add("cooked");
    // Whitespace text nodes between/inside blocks mirror real cooked HTML.
    container.innerHTML =
      "<p>Contribute by commenting and offering feedback.</p>\n" +
      "<blockquote>\n<p>If you need help, contact the admins.</p></blockquote>";
    document.body.appendChild(container);

    try {
      const paragraph = container.querySelector("p");
      const innerParagraph = container.querySelector("blockquote p");

      // A real triple-click on the paragraph over-extends the selection to
      // offset 0 of the next block's first child, so cloneContents() yields a
      // trailing <blockquote>\n<p></p></blockquote> (verified in Chromium).
      const range = document.createRange();
      range.setStart(paragraph.firstChild, 0);
      range.setEnd(innerParagraph, 0);

      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);

      const html = selectedHTML();

      assert.true(
        html.includes("Contribute by commenting"),
        "keeps the selected paragraph"
      );
      assert.false(
        html.includes("blockquote"),
        `drops the trailing empty blockquote (got: ${html})`
      );
    } finally {
      window.getSelection().removeAllRanges();
      container.remove();
    }
  });

  test("keeps a trailing block that wraps media", function (assert) {
    const container = document.createElement("div");
    container.classList.add("cooked");
    container.innerHTML =
      "<p>Intro.</p>" + "<p><img src='/uploads/cat.png' alt='cat'>caption</p>";
    document.body.appendChild(container);

    try {
      const paragraph = container.querySelector("p");
      const caption = container.querySelectorAll("p")[1].childNodes[1];

      // Selection ends at offset 0 of the caption text, so the second paragraph
      // clones to <p><img></p> — text-empty but still carrying the image.
      const range = document.createRange();
      range.setStart(paragraph.firstChild, 0);
      range.setEnd(caption, 0);

      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);

      const html = selectedHTML();

      assert.true(
        html.includes("cat.png"),
        `keeps a text-empty block that wraps media (got: ${html})`
      );
    } finally {
      window.getSelection().removeAllRanges();
      container.remove();
    }
  });

  test("quotes videos as video markdown", async function (assert) {
    const container = document.createElement("div");
    container.classList.add("cooked");
    container.innerHTML =
      "<p>Before</p><div class='video-placeholder-container' data-video-src='/uploads/clip.mp4' data-video-base62-sha1='abc'></div><div class='video-placeholder-container' data-video-src='/uploads/old.mp4'></div><div class='video-container' data-video-src='/uploads/played.mp4' data-video-base62-sha1='def'><video><source src='/uploads/played.mp4'></video></div><p>After</p>";
    fixture().append(container);

    await selectText(container);
    const markdown = await selectedText();

    assert.true(
      markdown.includes("![|video](upload://abc.mp4)"),
      `keeps the video as markdown (got: ${markdown})`
    );
    assert.true(
      markdown.includes("![|video](/uploads/old.mp4)"),
      `falls back to the video path (got: ${markdown})`
    );
    assert.true(
      markdown.includes("![|video](upload://def.mp4)"),
      `keeps played videos as markdown (got: ${markdown})`
    );
  });

  test("does not trim when the selection ends mid-content", function (assert) {
    const container = document.createElement("div");
    container.classList.add("cooked");
    container.innerHTML = "<p>First paragraph.</p><p>Second paragraph.</p>";
    document.body.appendChild(container);

    try {
      const [first, second] = container.querySelectorAll("p");

      // endOffset !== 0: a normal selection, never treated as over-extension.
      const range = document.createRange();
      range.setStart(first.firstChild, 0);
      range.setEnd(second.firstChild, 6);

      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);

      const html = selectedHTML();

      assert.true(
        html.includes("Second"),
        `keeps the partially-selected trailing block (got: ${html})`
      );
    } finally {
      window.getSelection().removeAllRanges();
      container.remove();
    }
  });
});

module("Unit | Utilities | clipboard", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.mockClipboard = {
      writeText: sinon.stub().resolves(true),
      write: sinon.stub().resolves(true),
    };
    sinon.stub(window.navigator, "clipboard").get(() => this.mockClipboard);
  });

  async function asyncFunction() {
    return new Blob(["some text to copy"], {
      type: "text/plain",
    });
  }

  test("clipboardCopyAsync - browser does not support window.ClipboardItem", async function (assert) {
    // without this check the stubbing will fail on Firefox
    if (window.ClipboardItem) {
      sinon.stub(window, "ClipboardItem").value(null);
    }

    await clipboardCopyAsync(asyncFunction);
    assert.true(
      this.mockClipboard.writeText.calledWith("some text to copy"),
      "writes to the clipboard using writeText instead of write"
    );
  });

  chromeTest(
    "clipboardCopyAsync - browser does support window.ClipboardItem",
    async function (assert) {
      await clipboardCopyAsync(asyncFunction);
      assert.strictEqual(
        this.mockClipboard.write.called,
        true,
        "it writes to the clipboard using write"
      );
    }
  );
});

module("Unit | Utilities | tables", function (hooks) {
  setupTest(hooks);

  test("findTableRegex", function (assert) {
    const oneTable = `|Make|Model|Year|\n|--- | --- | ---|\n|Toyota|Supra|1998|`;

    assert.strictEqual(
      oneTable.match(findTableRegex()).length,
      1,
      "finds one table in markdown"
    );

    const threeTables = `## Heading
|Table1 | PP Port | Device | DP | Medium|
|--- | --- | --- | --- | ---|
| Something | (1+2) | Dude | Mate | Bro |

|Table2 | PP Port | Device | DP | Medium|
|--- | --- | --- | --- | ---|
| Something | (1+2) | Dude | Mate | Bro |
| ✅  | (1+2) | Dude | Mate | Bro |
| ✅  | (1+2) | Dude | Mate | Bro |

|Table3 | PP Port | Device | DP |
|--- | --- | --- | --- |
| Something | (1+2) | Dude | Sound |
|  | (1+2) | Dude | OW |
|  | (1+2) | Dude | OI |

Random extras
    `;

    assert.strictEqual(
      threeTables.match(findTableRegex()).length,
      3,
      "finds three tables in markdown"
    );

    const ignoreUploads = `
:information_source: Something

[details=Example of a cross-connect in Equinix]
![image|603x500, 100%](upload://fURYa9mt00rXZITdYhhyeHFJE8J.png)
[/details]

|Table1 | PP Port | Device | DP | Medium|
|--- | --- | --- | --- | ---|
| Something | (1+2) | Dude | Mate | Bro |
`;
    assert.strictEqual(
      ignoreUploads.match(findTableRegex()).length,
      1,
      "finds on table, ignoring upload markup"
    );
  });
});

module("Unit | Utilities | translateModKey", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
    this.warnStub = sinon.stub(console, "warn");
  });

  hooks.afterEach(function () {
    this.warnStub.restore();
    enableRaiseOnDeprecation();
  });

  test("warns that it is deprecated", function (assert) {
    translateModKey("Shift+Ctrl+A");

    assert.strictEqual(this.warnStub.callCount, 1, "warns once per call");
    const warning = this.warnStub.firstCall.args[0];
    assert.true(
      warning.includes("DShortcut"),
      "points at the component that draws a shortcut"
    );
    assert.true(
      warning.includes("formatShortcut"),
      "and at the helper, for a caller that only wants the string"
    );
  });

  test("still translates while deprecated", function (assert) {
    const translated = withSilencedDeprecations(
      "discourse.translate-mod-key",
      () => translateModKey("Shift+Alt+A")
    );

    assert.true(
      translated.includes("⇧"),
      "keeps replacing modifier names with their platform spelling"
    );
  });
});
