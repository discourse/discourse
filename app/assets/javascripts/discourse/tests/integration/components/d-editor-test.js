import { click, fillIn, settled } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  paste,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import {
  getTextareaSelection,
  setTextareaSelection,
} from "discourse/tests/helpers/textarea-selection-helper";
import I18n from "I18n";
import { clearToolbarCallbacks } from "discourse/components/d-editor";
import formatTextWithSelection from "discourse/tests/helpers/d-editor-helper";
import hbs from "htmlbars-inline-precompile";
import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";

discourseModule("Integration | Component | d-editor", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("preview updates with markdown", {
    template: hbs`{{d-editor value=value}}`,

    async test(assert) {
      assert.ok(exists(".d-editor-button-bar"));
      await fillIn(".d-editor-input", "hello **world**");

      assert.strictEqual(this.value, "hello **world**");
      assert.strictEqual(
        queryAll(".d-editor-preview").html().trim(),
        "<p>hello <strong>world</strong></p>"
      );
    },
  });

  componentTest("links in preview are not tabbable", {
    template: hbs`{{d-editor value=value}}`,

    async test(assert) {
      await fillIn(".d-editor-input", "[discourse](https://www.discourse.org)");

      assert.strictEqual(
        queryAll(".d-editor-preview").html().trim(),
        '<p><a href="https://www.discourse.org" tabindex="-1">discourse</a></p>'
      );
    },
  });

  componentTest("preview sanitizes HTML", {
    template: hbs`{{d-editor value=value}}`,

    async test(assert) {
      await fillIn(".d-editor-input", `"><svg onload="prompt(/xss/)"></svg>`);
      assert.strictEqual(
        queryAll(".d-editor-preview").html().trim(),
        '<p>"&gt;</p>'
      );
    },
  });

  componentTest("updating the value refreshes the preview", {
    template: hbs`{{d-editor value=value}}`,

    beforeEach() {
      this.set("value", "evil trout");
    },

    async test(assert) {
      assert.strictEqual(
        queryAll(".d-editor-preview").html().trim(),
        "<p>evil trout</p>"
      );

      this.set("value", "zogstrip");
      await settled();

      assert.strictEqual(
        queryAll(".d-editor-preview").html().trim(),
        "<p>zogstrip</p>"
      );
    },
  });

  function jumpEnd(textarea) {
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;
    return textarea;
  }

  function testCase(title, testFunc) {
    componentTest(title, {
      template: hbs`{{d-editor value=value}}`,
      beforeEach() {
        this.set("value", "hello world.");
      },
      test(assert) {
        const textarea = jumpEnd(query("textarea.d-editor-input"));
        testFunc.call(this, assert, textarea);
      },
      skip: !navigator.userAgent.includes("Chrome"),
    });
  }

  function composerTestCase(title, testFunc) {
    componentTest(title, {
      template: hbs`{{d-editor value=value composerEvents=true}}`,
      beforeEach() {
        this.set("value", "hello world.");
      },

      test(assert) {
        const textarea = jumpEnd(query("textarea.d-editor-input"));
        testFunc.call(this, assert, textarea);
      },
    });
  }

  testCase(
    `selecting the space before a word`,
    async function (assert, textarea) {
      textarea.selectionStart = 5;
      textarea.selectionEnd = 7;

      await click(`button.bold`);

      assert.strictEqual(this.value, `hello **w**orld.`);
      assert.strictEqual(textarea.selectionStart, 8);
      assert.strictEqual(textarea.selectionEnd, 9);
    }
  );

  testCase(
    `selecting the space after a word`,
    async function (assert, textarea) {
      textarea.selectionStart = 0;
      textarea.selectionEnd = 6;

      await click(`button.bold`);

      assert.strictEqual(this.value, `**hello** world.`);
      assert.strictEqual(textarea.selectionStart, 2);
      assert.strictEqual(textarea.selectionEnd, 7);
    }
  );

  testCase(`bold button with no selection`, async function (assert, textarea) {
    await click(`button.bold`);

    const example = I18n.t(`composer.bold_text`);
    assert.strictEqual(this.value, `hello world.**${example}**`);
    assert.strictEqual(textarea.selectionStart, 14);
    assert.strictEqual(textarea.selectionEnd, 14 + example.length);
  });

  testCase(`bold button with a selection`, async function (assert, textarea) {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 11;

    await click(`button.bold`);
    assert.strictEqual(this.value, `hello **world**.`);
    assert.strictEqual(textarea.selectionStart, 8);
    assert.strictEqual(textarea.selectionEnd, 13);

    await click(`button.bold`);
    assert.strictEqual(this.value, "hello world.");
    assert.strictEqual(textarea.selectionStart, 6);
    assert.strictEqual(textarea.selectionEnd, 11);
  });

  testCase(
    `bold with a multiline selection`,
    async function (assert, textarea) {
      this.set("value", "hello\n\nworld\n\ntest.");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 12;

      await click(`button.bold`);
      assert.strictEqual(this.value, `**hello**\n\n**world**\n\ntest.`);
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 20);

      await click(`button.bold`);
      assert.strictEqual(this.value, `hello\n\nworld\n\ntest.`);
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 12);
    }
  );

  testCase(
    `italic button with no selection`,
    async function (assert, textarea) {
      await click(`button.italic`);
      const example = I18n.t(`composer.italic_text`);
      assert.strictEqual(this.value, `hello world.*${example}*`);

      assert.strictEqual(textarea.selectionStart, 13);
      assert.strictEqual(textarea.selectionEnd, 13 + example.length);
    }
  );

  testCase(`italic button with a selection`, async function (assert, textarea) {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 11;

    await click(`button.italic`);
    assert.strictEqual(this.value, `hello *world*.`);
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 12);

    await click(`button.italic`);
    assert.strictEqual(this.value, "hello world.");
    assert.strictEqual(textarea.selectionStart, 6);
    assert.strictEqual(textarea.selectionEnd, 11);
  });

  testCase(
    `italic with a multiline selection`,
    async function (assert, textarea) {
      this.set("value", "hello\n\nworld\n\ntest.");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 12;

      await click(`button.italic`);
      assert.strictEqual(this.value, `*hello*\n\n*world*\n\ntest.`);
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 16);

      await click(`button.italic`);
      assert.strictEqual(this.value, `hello\n\nworld\n\ntest.`);
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 12);
    }
  );

  componentTest("advanced code", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      this.siteSettings.code_formatting_style = "4-spaces-indent";
      this.set(
        "value",
        `
  function xyz(x, y, z) {
    if (y === z) {
      return true;
    }
  }
  `
      );
    },

    async test(assert) {
      const textarea = query("textarea.d-editor-input");
      textarea.selectionStart = 0;
      textarea.selectionEnd = textarea.value.length;

      await click("button.code");
      assert.strictEqual(
        this.value,
        `
      function xyz(x, y, z) {
        if (y === z) {
          return true;
        }
      }
  `
      );
    },
  });

  componentTest("code button", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      this.siteSettings.code_formatting_style = "4-spaces-indent";
    },

    async test(assert) {
      const textarea = jumpEnd(query("textarea.d-editor-input"));

      await click("button.code");
      assert.strictEqual(this.value, `    ${I18n.t("composer.code_text")}`);

      this.set("value", "first line\n\nsecond line\n\nthird line");

      textarea.selectionStart = 11;
      textarea.selectionEnd = 11;

      await click("button.code");
      assert.strictEqual(
        this.value,
        `first line
    ${I18n.t("composer.code_text")}
second line

third line`
      );

      this.set("value", "first line\n\nsecond line\n\nthird line");

      await click("button.code");
      assert.strictEqual(
        this.value,
        `first line

second line

third line\`${I18n.t("composer.code_title")}\``
      );
      this.set("value", "first line\n\nsecond line\n\nthird line");

      textarea.selectionStart = 5;
      textarea.selectionEnd = 5;

      await click("button.code");
      assert.strictEqual(
        this.value,
        `first\`${I18n.t("composer.code_title")}\` line

second line

third line`
      );
      this.set("value", "first line\n\nsecond line\n\nthird line");

      textarea.selectionStart = 6;
      textarea.selectionEnd = 10;

      await click("button.code");
      assert.strictEqual(
        this.value,
        "first `line`\n\nsecond line\n\nthird line"
      );
      assert.strictEqual(textarea.selectionStart, 7);
      assert.strictEqual(textarea.selectionEnd, 11);

      await click("button.code");
      assert.strictEqual(this.value, "first line\n\nsecond line\n\nthird line");
      assert.strictEqual(textarea.selectionStart, 6);
      assert.strictEqual(textarea.selectionEnd, 10);

      textarea.selectionStart = 0;
      textarea.selectionEnd = 23;

      await click("button.code");
      assert.strictEqual(
        this.value,
        "    first line\n\n    second line\n\nthird line"
      );
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 31);

      await click("button.code");
      assert.strictEqual(this.value, "first line\n\nsecond line\n\nthird line");
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 23);
    },
  });

  componentTest("code fences", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      this.set("value", "");
    },

    async test(assert) {
      const textarea = jumpEnd(query("textarea.d-editor-input"));

      await click("button.code");
      assert.strictEqual(
        this.value,
        `\`\`\`
${I18n.t("composer.paste_code_text")}
\`\`\``
      );

      assert.strictEqual(textarea.selectionStart, 4);
      assert.strictEqual(textarea.selectionEnd, 27);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = textarea.value.length;

      await click("button.code");

      assert.strictEqual(
        this.value,
        `\`\`\`
first line
second line
third line
\`\`\`
`
      );

      assert.strictEqual(textarea.selectionStart, textarea.value.length);
      assert.strictEqual(textarea.selectionEnd, textarea.value.length);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 0;

      await click("button.code");

      assert.strictEqual(
        this.value,
        `\`${I18n.t("composer.code_title")}\`first line
second line
third line`
      );

      assert.strictEqual(textarea.selectionStart, 1);
      assert.strictEqual(
        textarea.selectionEnd,
        I18n.t("composer.code_title").length + 1
      );

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 10;

      await click("button.code");

      assert.strictEqual(
        this.value,
        `\`first line\`
second line
third line`
      );

      assert.strictEqual(textarea.selectionStart, 1);
      assert.strictEqual(textarea.selectionEnd, 11);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 23;

      await click("button.code");

      assert.strictEqual(
        this.value,
        `\`\`\`
first line
second line
\`\`\`
third line`
      );

      assert.strictEqual(textarea.selectionStart, 30);
      assert.strictEqual(textarea.selectionEnd, 30);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 6;
      textarea.selectionEnd = 17;

      await click("button.code");

      assert.strictEqual(
        this.value,
        `first \n\`\`\`\nline\nsecond\n\`\`\`\n line\nthird line`
      );

      assert.strictEqual(textarea.selectionStart, 27);
      assert.strictEqual(textarea.selectionEnd, 27);
    },
  });

  componentTest("quote button - empty lines", {
    template: hbs`{{d-editor value=value composerEvents=true}}`,
    beforeEach() {
      this.set("value", "one\n\ntwo\n\nthree");
    },
    async test(assert) {
      const textarea = jumpEnd(query("textarea.d-editor-input"));

      textarea.selectionStart = 0;

      await click("button.blockquote");

      assert.strictEqual(this.value, "> one\n> \n> two\n> \n> three");
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 25);

      await click("button.blockquote");
      assert.strictEqual(this.value, "one\n\ntwo\n\nthree");
    },
  });

  componentTest("quote button - selecting empty lines", {
    template: hbs`{{d-editor value=value composerEvents=true}}`,
    beforeEach() {
      this.set("value", "one\n\n\n\ntwo");
    },
    async test(assert) {
      const textarea = jumpEnd(query("textarea.d-editor-input"));

      textarea.selectionStart = 6;
      textarea.selectionEnd = 10;

      await click("button.blockquote");
      assert.strictEqual(this.value, "one\n\n\n> \n> two");
    },
  });

  testCase("quote button", async function (assert, textarea) {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 9;

    await click("button.blockquote");
    assert.strictEqual(this.value, "hello\n\n> wor\n\nld.");
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 12);

    await click("button.blockquote");

    assert.strictEqual(this.value, "hello\n\nwor\n\nld.");
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 10);

    textarea.selectionStart = 15;
    textarea.selectionEnd = 15;

    await click("button.blockquote");
    assert.strictEqual(this.value, "hello\n\nwor\n\nld.\n\n> Blockquote");
  });

  testCase(
    `bullet button with no selection`,
    async function (assert, textarea) {
      const example = I18n.t("composer.list_item");

      await click(`button.bullet`);
      assert.strictEqual(this.value, `hello world.\n\n* ${example}`);
      assert.strictEqual(textarea.selectionStart, 14);
      assert.strictEqual(textarea.selectionEnd, 16 + example.length);

      await click(`button.bullet`);
      assert.strictEqual(this.value, `hello world.\n\n${example}`);
    }
  );

  testCase(`bullet button with a selection`, async function (assert, textarea) {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 11;

    await click(`button.bullet`);
    assert.strictEqual(this.value, `hello\n\n* world\n\n.`);
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 14);

    await click(`button.bullet`);
    assert.strictEqual(this.value, `hello\n\nworld\n\n.`);
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 12);
  });

  testCase(
    `bullet button with a multiple line selection`,
    async function (assert, textarea) {
      this.set("value", "* Hello\n\nWorld\n\nEvil");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 20;

      await click(`button.bullet`);
      assert.strictEqual(this.value, "Hello\n\nWorld\n\nEvil");
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 18);

      await click(`button.bullet`);
      assert.strictEqual(this.value, "* Hello\n\n* World\n\n* Evil");
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 24);
    }
  );

  testCase(`list button with no selection`, async function (assert, textarea) {
    const example = I18n.t("composer.list_item");

    await click(`button.list`);
    assert.strictEqual(this.value, `hello world.\n\n1. ${example}`);
    assert.strictEqual(textarea.selectionStart, 14);
    assert.strictEqual(textarea.selectionEnd, 17 + example.length);

    await click(`button.list`);
    assert.strictEqual(this.value, `hello world.\n\n${example}`);
    assert.strictEqual(textarea.selectionStart, 14);
    assert.strictEqual(textarea.selectionEnd, 14 + example.length);
  });

  testCase(`list button with a selection`, async function (assert, textarea) {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 11;

    await click(`button.list`);
    assert.strictEqual(this.value, `hello\n\n1. world\n\n.`);
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 15);

    await click(`button.list`);
    assert.strictEqual(this.value, `hello\n\nworld\n\n.`);
    assert.strictEqual(textarea.selectionStart, 7);
    assert.strictEqual(textarea.selectionEnd, 12);
  });

  testCase(`list button with line sequence`, async function (assert, textarea) {
    this.set("value", "Hello\n\nWorld\n\nEvil");

    textarea.selectionStart = 0;
    textarea.selectionEnd = 18;

    await click(`button.list`);
    assert.strictEqual(this.value, "1. Hello\n\n2. World\n\n3. Evil");
    assert.strictEqual(textarea.selectionStart, 0);
    assert.strictEqual(textarea.selectionEnd, 27);

    await click(`button.list`);
    assert.strictEqual(this.value, "Hello\n\nWorld\n\nEvil");
    assert.strictEqual(textarea.selectionStart, 0);
    assert.strictEqual(textarea.selectionEnd, 18);
  });

  componentTest("clicking the toggle-direction changes dir from ltr to rtl", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      this.siteSettings.support_mixed_text_direction = true;
      this.siteSettings.default_locale = "en";
    },

    async test(assert) {
      const textarea = queryAll("textarea.d-editor-input");
      await click("button.toggle-direction");
      assert.strictEqual(textarea.attr("dir"), "rtl");
    },
  });

  componentTest("clicking the toggle-direction changes dir from ltr to rtl", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      this.siteSettings.support_mixed_text_direction = true;
      this.siteSettings.default_locale = "en";
    },

    async test(assert) {
      const textarea = queryAll("textarea.d-editor-input");
      textarea.attr("dir", "ltr");
      await click("button.toggle-direction");
      assert.strictEqual(textarea.attr("dir"), "rtl");
    },
  });

  testCase(
    `doesn't jump to bottom with long text`,
    async function (assert, textarea) {
      let longText = "hello world.";
      for (let i = 0; i < 8; i++) {
        longText = longText + longText;
      }
      this.set("value", longText);

      $(textarea).scrollTop(0);
      textarea.selectionStart = 3;
      textarea.selectionEnd = 3;

      await click("button.bold");
      assert.strictEqual($(textarea).scrollTop(), 0, "it stays scrolled up");
    }
  );

  componentTest("emoji", {
    template: hbs`{{d-editor value=value}}`,
    beforeEach() {
      // Test adding a custom button
      withPluginApi("0.1", (api) => {
        api.onToolbarCreate((toolbar) => {
          toolbar.addButton({
            id: "emoji",
            group: "extras",
            icon: "far-smile",
            action: () => toolbar.context.send("emoji"),
          });
        });
      });
      this.set("value", "hello world.");
    },

    afterEach() {
      clearToolbarCallbacks();
    },

    async test(assert) {
      jumpEnd(query("textarea.d-editor-input"));
      await click("button.emoji");

      await click(
        '.emoji-picker .section[data-section="smileys_&_emotion"] img.emoji[title="grinning"]'
      );
      assert.strictEqual(this.value, "hello world. :grinning:");
    },
  });

  testCase("replace-text event by default", async function (assert) {
    this.set("value", "red green blue");

    await this.container
      .lookup("service:app-events")
      .trigger("composer:replace-text", "green", "yellow");

    assert.strictEqual(this.value, "red green blue");
  });

  composerTestCase("replace-text event for composer", async function (assert) {
    this.set("value", "red green blue");

    await this.container
      .lookup("service:app-events")
      .trigger("composer:replace-text", "green", "yellow");

    assert.strictEqual(this.value, "red yellow blue");
  });

  async function indentSelection(container, direction) {
    await container
      .lookup("service:app-events")
      .trigger("composer:indent-selected-text", direction);
  }

  composerTestCase(
    "indents a single line of text to the right",
    async function (assert, textarea) {
      this.set("value", "Hello world");
      setTextareaSelection(textarea, 0, textarea.value.length);
      await indentSelection(this.container, "right");

      assert.strictEqual(
        this.value,
        "  Hello world",
        "a single line of selection is indented correctly"
      );
    }
  );

  composerTestCase(
    "de-indents a single line of text to the left",
    async function (assert, textarea) {
      this.set("value", "  Hello world");
      setTextareaSelection(textarea, 0, textarea.value.length);
      await indentSelection(this.container, "left");

      assert.strictEqual(
        this.value,
        "Hello world",
        "a single line of selection is deindented correctly"
      );
    }
  );

  composerTestCase(
    "indents multiple lines of text to the right",
    async function (assert, textarea) {
      this.set("value", "  Hello world\nThis is me");
      setTextareaSelection(textarea, 2, textarea.value.length);
      await indentSelection(this.container, "right");

      assert.strictEqual(
        this.value,
        "    Hello world\n  This is me",
        "multiple lines are indented correctly without selecting preceding space"
      );

      this.set("value", "  Hello world\nThis is me");
      setTextareaSelection(textarea, 0, textarea.value.length);
      await indentSelection(this.container, "right");

      assert.strictEqual(
        this.value,
        "    Hello world\n  This is me",
        "multiple lines are indented correctly with selecting preceding space"
      );
    }
  );

  composerTestCase(
    "de-indents multiple lines of text to the left",
    async function (assert, textarea) {
      this.set("value", "  Hello world\nThis is me");
      setTextareaSelection(textarea, 2, textarea.value.length);
      await indentSelection(this.container, "left");

      assert.strictEqual(
        this.value,
        "Hello world\nThis is me",
        "multiple lines are de-indented correctly without selecting preceding space"
      );
    }
  );

  composerTestCase(
    "detects the indentation character (tab vs. string) and uses that",
    async function (assert, textarea) {
      this.set(
        "value",
        "```\nfunc init() {\n	strings = generateStrings()\n}\n```"
      );
      setTextareaSelection(textarea, 4, textarea.value.length - 4);
      await indentSelection(this.container, "right");

      assert.strictEqual(
        this.value,
        "```\n	func init() {\n		strings = generateStrings()\n	}\n```",
        "detects the prevalent indentation character and uses that (tab)"
      );
    }
  );

  componentTest("paste table", {
    template: hbs`{{d-editor value=value composerEvents=true}}`,
    beforeEach() {
      this.set("value", "");
      this.siteSettings.enable_rich_text_paste = true;
    },

    async test(assert) {
      let element = query(".d-editor");
      await paste(element, "\ta\tb\n1\t2\t3");
      assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2|3|\n");
    },
  });

  componentTest("paste a different table", {
    template: hbs`{{d-editor value=value composerEvents=true}}`,
    beforeEach() {
      this.set("value", "");
      this.siteSettings.enable_rich_text_paste = true;
    },

    async test(assert) {
      let element = query(".d-editor");
      await paste(element, '\ta\tb\n1\t"2\n2.5"\t3');
      assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2<br>2.5|3|\n");
    },
  });

  testCase(
    `pasting a link into a selection applies a link format`,
    async function (assert, textarea) {
      this.set("value", "See discourse in action");
      setTextareaSelection(textarea, 4, 13);
      const element = query(".d-editor");
      const event = await paste(element, "https://www.discourse.org/");
      assert.strictEqual(
        this.value,
        "See [discourse](https://www.discourse.org/) in action"
      );
      assert.strictEqual(event.defaultPrevented, true);
    }
  );

  testCase(
    `pasting other text into a selection will replace text value`,
    async function (assert, textarea) {
      this.set("value", "good morning");
      setTextareaSelection(textarea, 5, 12);
      const element = query(".d-editor");
      const event = await paste(element, "evening");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "good morning");
      assert.strictEqual(event.defaultPrevented, false);
    }
  );

  testCase(
    `pasting a url without a selection will insert the url`,
    async function (assert, textarea) {
      this.set("value", "a link example:");
      jumpEnd(textarea);
      const element = query(".d-editor");
      const event = await paste(element, "https://www.discourse.org/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "a link example:");
      assert.strictEqual(event.defaultPrevented, false);
    }
  );

  testCase(
    `pasting text that contains urls and other content will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "a link example:");
      setTextareaSelection(textarea, 0, 1);
      const element = query(".d-editor");
      const event = await paste(
        element,
        "Try out Discourse at: https://www.discourse.org/"
      );
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "a link example:");
      assert.strictEqual(event.defaultPrevented, false);
    }
  );

  testCase(
    `pasting an email into a selection applies a link format`,
    async function (assert, textarea) {
      this.set("value", "team email");
      setTextareaSelection(textarea, 5, 10);
      const element = query(".d-editor");
      const event = await paste(element, "mailto:team@discourse.org");
      assert.strictEqual(this.value, "team [email](mailto:team@discourse.org)");
      assert.strictEqual(event.defaultPrevented, true);
    }
  );

  testCase(
    `pasting a url onto a selection that contains urls and other content will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "Try https://www.discourse.org");
      setTextareaSelection(textarea, 0, 29);
      const element = query(".d-editor");
      const event = await paste(element, "https://www.discourse.com/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "Try https://www.discourse.org");
      assert.strictEqual(event.defaultPrevented, false);
    }
  );

  testCase(
    `pasting a url onto a selection that contains bbcode-like tags will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "hello [url=foobar]foobar[/url]");
      setTextareaSelection(textarea, 0, 30);
      const element = query(".d-editor");
      const event = await paste(element, "https://www.discourse.com/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "hello [url=foobar]foobar[/url]");
      assert.strictEqual(event.defaultPrevented, false);
    }
  );

  (() => {
    // Tests to check cursor/selection after replace-text event.
    const BEFORE = "red green blue";
    const NEEDLE = "green";
    const REPLACE = "yellow";
    const AFTER = BEFORE.replace(NEEDLE, REPLACE);

    const CASES = [
      {
        description: "cursor at start remains there",
        before: [0, 0],
        after: [0, 0],
      },
      {
        description: "cursor before needle becomes cursor before replacement",
        before: [BEFORE.indexOf(NEEDLE), 0],
        after: [AFTER.indexOf(REPLACE), 0],
      },
      {
        description: "cursor at needle start + 1 moves behind replacement",
        before: [BEFORE.indexOf(NEEDLE) + 1, 0],
        after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0],
      },
      {
        description: "cursor at needle end - 1 stays behind replacement",
        before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length - 1, 0],
        after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0],
      },
      {
        description: "cursor behind needle becomes cursor behind replacement",
        before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length, 0],
        after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0],
      },
      {
        description: "cursor at end remains there",
        before: [BEFORE.length, 0],
        after: [AFTER.length, 0],
      },
      {
        description:
          "selection spanning needle start becomes selection until replacement start",
        before: [BEFORE.indexOf(NEEDLE) - 1, 2],
        after: [AFTER.indexOf(REPLACE) - 1, 1],
      },
      {
        description:
          "selection spanning needle end becomes selection from replacement end",
        before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length - 1, 2],
        after: [AFTER.indexOf(REPLACE) + REPLACE.length, 1],
      },
      {
        description:
          "selection spanning needle becomes selection spanning replacement",
        before: [BEFORE.indexOf(NEEDLE) - 1, NEEDLE.length + 2],
        after: [AFTER.indexOf(REPLACE) - 1, REPLACE.length + 2],
      },
      {
        description: "complete selection remains complete",
        before: [0, BEFORE.length],
        after: [0, AFTER.length],
      },
    ];

    for (let i = 0; i < CASES.length; i++) {
      const CASE = CASES[i];
      // prettier-ignore
      composerTestCase(`replace-text event: ${CASE.description}`, async function( // eslint-disable-line no-loop-func
        assert,
        textarea
      ) {
        this.set("value", BEFORE);

        await focus(textarea);

        assert.ok(textarea.value === BEFORE);

        const [start, len] = CASE.before;
        setTextareaSelection(textarea, start, start + len);

        this.container
          .lookup("service:app-events")
          .trigger("composer:replace-text", "green", "yellow", { forceFocus: true });

        next(() => {
          let expect = formatTextWithSelection(AFTER, CASE.after);
          let actual = formatTextWithSelection(
            this.value,
            getTextareaSelection(textarea)
          );
          assert.strictEqual(actual, expect);
        });
      });
    }
  })();
});
