import { next } from "@ember/runloop";
import {
  click,
  fillIn,
  focus,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setCaretPosition } from "discourse/lib/utilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formatTextWithSelection from "discourse/tests/helpers/d-editor-helper";
import { paste, query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import {
  getTextareaSelection,
  setTextareaSelection,
} from "discourse/tests/helpers/textarea-selection-helper";
import I18n from "discourse-i18n";

module("Integration | Component | d-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("preview updates with markdown", async function (assert) {
    await render(hbs`<DEditor @value={{this.value}} />`);

    assert.dom(".d-editor-button-bar").exists();
    await fillIn(".d-editor-input", "hello **world**");

    assert.strictEqual(this.value, "hello **world**");
    assert.strictEqual(
      query(".d-editor-preview").innerHTML.trim(),
      "<p>hello <strong>world</strong></p>"
    );
  });

  test("links in preview are not tabbable", async function (assert) {
    await render(hbs`<DEditor @value={{this.value}} />`);

    await fillIn(".d-editor-input", "[discourse](https://www.discourse.org)");

    assert.strictEqual(
      query(".d-editor-preview").innerHTML.trim(),
      '<p><a href="https://www.discourse.org" tabindex="-1">discourse</a></p>'
    );
  });

  test("updating the value refreshes the preview", async function (assert) {
    this.set("value", "evil trout");

    await render(hbs`<DEditor @value={{this.value}} />`);

    assert.strictEqual(
      query(".d-editor-preview").innerHTML.trim(),
      "<p>evil trout</p>"
    );

    this.set("value", "zogstrip");
    await settled();

    assert.strictEqual(
      query(".d-editor-preview").innerHTML.trim(),
      "<p>zogstrip</p>"
    );
  });

  function jumpEnd(textarea) {
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;
    return textarea;
  }

  function testCase(title, testFunc) {
    test(title, async function (assert) {
      this.set("value", "hello world.");

      await render(hbs`<DEditor @value={{this.value}} />`);

      const textarea = jumpEnd(query("textarea.d-editor-input"));
      await testFunc.call(this, assert, textarea);
    });
  }

  function composerTestCase(title, testFunc) {
    test(title, async function (assert) {
      this.set("value", "hello world.");

      await render(
        hbs`<DEditor @value={{this.value}} @composerEvents={{true}} />`
      );

      const textarea = jumpEnd(query("textarea.d-editor-input"));
      await testFunc.call(this, assert, textarea);
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
    "bold button maintains undo history",
    async function (assert, textarea) {
      textarea.selectionStart = 6;
      textarea.selectionEnd = 11;

      await click("button.bold");
      assert.strictEqual(this.value, "hello **world**.");
      assert.strictEqual(textarea.selectionStart, 8);
      assert.strictEqual(textarea.selectionEnd, 13);

      document.execCommand("undo");
      assert.strictEqual(this.value, "hello world.");
    }
  );

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

  test("advanced code", async function (assert) {
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

    await render(hbs`<DEditor @value={{this.value}} />`);

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
  });

  test("code button", async function (assert) {
    this.siteSettings.code_formatting_style = "4-spaces-indent";

    await render(hbs`<DEditor @value={{this.value}} />`);

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
    assert.strictEqual(this.value, "first `line`\n\nsecond line\n\nthird line");
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
  });

  test("code fences", async function (assert) {
    this.set("value", "");

    await render(hbs`<DEditor @value={{this.value}} />`);

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

    document.execCommand("undo");
    assert.strictEqual(this.value, "first line\nsecond line\nthird line");
  });

  test("quote button - empty lines", async function (assert) {
    this.set("value", "one\n\ntwo\n\nthree");

    await render(
      hbs`<DEditor @value={{this.value}} @composerEvents={{true}} />`
    );

    const textarea = jumpEnd(query("textarea.d-editor-input"));

    textarea.selectionStart = 0;

    await click("button.blockquote");

    assert.strictEqual(this.value, "> one\n> \n> two\n> \n> three");
    assert.strictEqual(textarea.selectionStart, 0);
    assert.strictEqual(textarea.selectionEnd, 25);

    await click("button.blockquote");
    assert.strictEqual(this.value, "one\n\ntwo\n\nthree");
  });

  test("quote button - selecting empty lines", async function (assert) {
    this.set("value", "one\n\n\n\ntwo");

    await render(
      hbs`<DEditor @value={{this.value}} @composerEvents={{true}} />`
    );

    const textarea = jumpEnd(query("textarea.d-editor-input"));

    textarea.selectionStart = 6;
    textarea.selectionEnd = 10;

    await click("button.blockquote");
    assert.strictEqual(this.value, "one\n\n\n> \n> two");

    document.execCommand("undo");
    assert.strictEqual(this.value, "one\n\n\n\ntwo");
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

  test("clicking the toggle-direction changes dir from ltr to rtl", async function (assert) {
    this.siteSettings.support_mixed_text_direction = true;
    this.siteSettings.default_locale = "en";

    await render(hbs`<DEditor @value={{this.value}} />`);

    await click("button.toggle-direction");
    assert.strictEqual(
      query("textarea.d-editor-input").getAttribute("dir"),
      "rtl"
    );
  });

  test("clicking the toggle-direction changes dir from ltr to rtl", async function (assert) {
    this.siteSettings.support_mixed_text_direction = true;
    this.siteSettings.default_locale = "en";

    await render(hbs`<DEditor @value={{this.value}} />`);

    const textarea = query("textarea.d-editor-input");
    textarea.setAttribute("dir", "ltr");
    await click("button.toggle-direction");
    assert.strictEqual(textarea.getAttribute("dir"), "rtl");
  });

  test("toolbar event supports replaceText", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "replace-text",
          icon: "xmark",
          group: "extras",
          action: () => {
            toolbar.context.newToolbarEvent().replaceText("hello", "goodbye");
          },
          condition: () => true,
        });
      });
    });

    this.value = "hello";

    await render(hbs`<DEditor @value={{this.value}} />`);
    await click("button.replace-text");

    assert.strictEqual(this.value, "goodbye");
  });

  testCase(
    `doesn't jump to bottom with long text`,
    async function (assert, textarea) {
      this.set("value", "hello world.".repeat(8));

      textarea.scrollTop = 0;
      textarea.selectionStart = 3;
      textarea.selectionEnd = 3;

      await click("button.bold");
      assert.strictEqual(textarea.scrollTop, 0, "it stays scrolled up");
    }
  );

  test("emoji", async function (assert) {
    // Test adding a custom button
    withPluginApi("0.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "far-face-smile",
          action: () => toolbar.context.send("emoji"),
        });
      });
    });
    this.set("value", "hello world.");

    await render(hbs`<DEditor @value={{this.value}} />`);

    jumpEnd(query("textarea.d-editor-input"));
    await click("button.emoji");

    await click(
      '.emoji-picker .section[data-section="smileys_&_emotion"] img.emoji[title="grinning"]'
    );
    assert.strictEqual(
      this.value,
      "hello world. :grinning:",
      "it works when there is no partial emoji"
    );

    await click("textarea.d-editor-input");
    await fillIn(".d-editor-input", "starting to type an emoji like :gri");
    jumpEnd(query("textarea.d-editor-input"));
    await click("button.emoji");

    await click(
      '.emoji-picker .section[data-section="smileys_&_emotion"] img.emoji[title="grinning"]'
    );
    assert.strictEqual(
      this.value,
      "starting to type an emoji like :grinning:",
      "it works when there is a partial emoji"
    );
  });

  test("Toolbar buttons are only rendered when condition is met", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "shown",
          group: "extras",
          icon: "far-face-smile",
          action: () => {},
          condition: () => true,
        });

        toolbar.addButton({
          id: "not-shown",
          group: "extras",
          icon: "far-face-frown",
          action: () => {},
          condition: () => false,
        });
      });
    });

    await render(hbs`<DEditor/>`);

    assert.dom(".d-editor-button-bar button.shown").exists();
    assert.dom(".d-editor-button-bar button.not-shown").doesNotExist();
  });

  test("toolbar buttons tabindex", async function (assert) {
    await render(hbs`<DEditor />`);
    const buttons = queryAll(".d-editor-button-bar .btn");

    assert.strictEqual(
      buttons[0].getAttribute("tabindex"),
      "0",
      "it makes the first button focusable"
    );
    assert.strictEqual(buttons[1].getAttribute("tabindex"), "-1");
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

  test("paste table", async function (assert) {
    this.set("value", "");
    this.siteSettings.enable_rich_text_paste = true;

    await render(
      hbs`<DEditor @value={{this.value}} @composerEvents={{true}} />`
    );

    let element = query(".d-editor");
    await paste(element, "\ta\tb\n1\t2\t3");
    assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2|3|\n");

    document.execCommand("undo");
    assert.strictEqual(this.value, "");
  });

  test("paste a different table", async function (assert) {
    this.set("value", "");
    this.siteSettings.enable_rich_text_paste = true;

    await render(
      hbs`<DEditor @value={{this.value}} @composerEvents={{true}} />`
    );

    let element = query(".d-editor");
    await paste(element, '\ta\tb\n1\t"2\n2.5"\t3');
    assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2<br>2.5|3|\n");
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

      document.execCommand("undo");
      assert.strictEqual(this.value, "See discourse in action");
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

  // Smart list functionality relies on beforeinput, which QUnit does not send with
  // `typeIn` synthetic events. We need to send it ourselves manually along with `input`.
  // Not ideal, but gets the job done.
  //
  // c.f. https://github.com/emberjs/ember-test-helpers/blob/master/API.md#typein and
  // https://github.com/emberjs/ember-test-helpers/issues/1336
  async function triggerEnter(textarea) {
    await triggerEvent(textarea, "beforeinput", {
      inputType: "insertLineBreak",
    });
    await triggerEvent(textarea, "input", {
      inputType: "insertText",
      data: "\n",
    });
  }

  testCase(
    "smart lists - pressing enter on a line with a list item starting with *",
    async function (assert, textarea) {
      const initialValue = "* first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);

      assert.strictEqual(
        this.value,
        initialValue + "* ",
        "it creates a list item on the next line"
      );
    }
  );

  testCase(
    "smart lists - pressing enter on a line with a list item inside a codefence",
    async function (assert, textarea) {
      const initialValue = "```\n* first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);

      assert.strictEqual(
        this.value,
        initialValue + "",
        "it doesn’t continue the list"
      );
    }
  );

  testCase(
    "smart lists - pressing enter on a line with a list item after a codefence",
    async function (assert, textarea) {
      const initialValue = "```\ndef test\n```\n* first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);

      assert.strictEqual(
        this.value,
        initialValue + "* ",
        "it continues the list"
      );
    }
  );

  testCase(
    "smart lists - pressing enter on a line with a list item starting with - creates a list item on the next line",
    async function (assert, textarea) {
      const initialValue = "- first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);
      assert.strictEqual(this.value, initialValue + "- ");
    }
  );

  testCase(
    "smart lists - pressing enter on a line with a list item starting with a number (e.g. 1.) in a list",
    async function (assert, textarea) {
      const initialValue = "1. first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);
      assert.strictEqual(
        this.value,
        initialValue + "2. ",
        "it creates a list item on the next line with an auto-incremented number"
      );
    }
  );

  testCase(
    "smart lists - pressing enter inside a list",
    async function (assert, textarea) {
      const initialValue = "* first item in list\n\n* second item in list";
      this.set("value", initialValue);
      setCaretPosition(textarea, 21);
      await triggerEnter(textarea);
      assert.strictEqual(
        this.value,
        "* first item in list\n* \n* second item in list",
        "it inserts a new list item on the next line"
      );
    }
  );

  testCase(
    "smart lists - pressing enter inside a list with numbers",
    async function (assert, textarea) {
      const initialValue = "1. first item in list\n\n2. second item in list";
      this.set("value", initialValue);
      setCaretPosition(textarea, 22);
      await triggerEnter(textarea);
      assert.strictEqual(
        this.value,
        "1. first item in list\n2. \n3. second item in list",
        "it inserts a new list item on the next line and renumbers the rest of the list"
      );
    }
  );

  testCase(
    "smart lists - pressing enter again on an empty list item",
    async function (assert, textarea) {
      const initialValue = "* first item in list with empty line\n* \n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);
      assert.strictEqual(
        this.value,
        "* first item in list with empty line\n",
        "it removes the list item"
      );
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
      composerTestCase(`replace-text event: ${CASE.description}`, async function(
        assert,
        textarea
      ) {
        this.set("value", BEFORE);

        await focus(textarea);

        assert.strictEqual(textarea.value, BEFORE);

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
