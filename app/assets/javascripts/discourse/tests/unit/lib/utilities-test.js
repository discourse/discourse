import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import Handlebars from "handlebars";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  arrayToTable,
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
  setCaretPosition,
  setDefaultHomepage,
  slugify,
  toAsciiPrintable,
  unicodeSlugify,
} from "discourse/lib/utilities";
import {
  mdTable,
  mdTableNonUniqueHeadings,
  mdTableSpecialChars,
} from "discourse/tests/fixtures/md-table";
import { chromeTest } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utilities", function (hooks) {
  setupTest(hooks);

  test("escapeExpression", function (assert) {
    assert.strictEqual(
      escapeExpression(">"),
      "&gt;",
      "escapes unsafe characters"
    );

    assert.strictEqual(
      escapeExpression(new Handlebars.SafeString("&gt;")),
      "&gt;",
      "does not double-escape safe strings"
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

module("Unit | Utilities | table-builder", function (hooks) {
  setupTest(hooks);

  test("arrayToTable", function (assert) {
    const tableData = [
      {
        col0: "Toyota",
        col1: "Supra",
        col2: "1998",
      },
      {
        col0: "Nissan",
        col1: "Skyline",
        col2: "1999",
      },
      {
        col0: "Honda",
        col1: "S2000",
        col2: "2001",
      },
    ];

    assert.strictEqual(
      arrayToTable(tableData, ["Make", "Model", "Year"]),
      mdTable,
      "it creates a markdown table from an array of objects (with headers as keys)"
    );

    const specialCharsTableData = [
      {
        col0: "Toyota",
        col1: "Supra",
        col2: "$50,000",
      },
      {
        col0: "",
        col1: "Celica",
        col2: "$20,000",
      },
      {
        col0: "Nissan",
        col1: "GTR",
        col2: "$80,000",
      },
    ];

    assert.strictEqual(
      arrayToTable(specialCharsTableData, ["Make", "Model", "Price"]),
      mdTableSpecialChars,
      "it creates a markdown table with special characters in correct alignment"
    );

    const nonUniqueColumns = ["col1", "col2", "col1"];

    assert.strictEqual(
      arrayToTable(
        [{ col0: "Col A", col1: "Col B", col2: "Col C" }],
        nonUniqueColumns
      ),
      mdTableNonUniqueHeadings,
      "it does not suppress a column if heading is the same as another column"
    );
  });
  test("arrayToTable with custom column prefix", function (assert) {
    const tableData = [
      {
        A0: "hey",
        A1: "you",
      },
      {
        A0: "over",
        A1: "there",
      },
    ];

    assert.strictEqual(
      arrayToTable(tableData, ["Col 1", "Col 2"], "A"),
      `|Col 1 | Col 2|\n|--- | ---|\n|hey | you|\n|over | there|\n`,
      "it works"
    );
  });

  test("arrayToTable returns valid table with multiline cell data", function (assert) {
    const tableData = [
      {
        col0: "Jane\nDoe",
        col1: "Teri",
      },
      {
        col0: "Finch",
        col1: "Sami",
      },
    ];

    assert.strictEqual(
      arrayToTable(tableData, ["Col 1", "Col 2"]),
      `|Col 1 | Col 2|\n|--- | ---|\n|Jane Doe | Teri|\n|Finch | Sami|\n`,
      "it creates a valid table"
    );
  });

  test("arrayToTable with alignment specification", function (assert) {
    const tableData = [
      { col0: "left", col1: "center", col2: "right", col3: "unspecificated" },
      { col0: "111", col1: "222", col2: "333", col3: "444" },
    ];
    const alignment = ["left", "center", "right", null];
    assert.strictEqual(
      arrayToTable(
        tableData,
        ["Col 1", "Col 2", "Col 3", "Col 4"],
        "col",
        alignment
      ),
      "|Col 1 | Col 2 | Col 3 | Col 4|\n|:-- | :-: | --: | ---|\n|left | center | right | unspecificated|\n|111 | 222 | 333 | 444|\n",
      "it creates a valid table"
    );
  });

  test("arrayToTable should escape `|`", function (assert) {
    const tableData = [
      {
        col0: "`a|b`",
        col1: "![image|200x50](/images/discourse-logo-sketch.png)",
        col2: "",
        col3: "|",
      },
      { col0: "1|1", col1: "2|2", col2: "3|3", col3: "4|4" },
    ];
    assert.strictEqual(
      arrayToTable(tableData, ["Col 1", "Col 2", "Col 3", "Col 4"]),
      "|Col 1 | Col 2 | Col 3 | Col 4|\n|--- | --- | --- | ---|\n|`a\\|b` | ![image\\|200x50](/images/discourse-logo-sketch.png) |  | \\||\n|1\\|1 | 2\\|2 | 3\\|3 | 4\\|4|\n",
      "it creates a valid table"
    );
  });

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
