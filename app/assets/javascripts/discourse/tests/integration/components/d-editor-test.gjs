import { next } from "@ember/runloop";
import {
  click,
  fillIn,
  find,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DEditor from "discourse/components/d-editor";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setCaretPosition } from "discourse/lib/utilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formatTextWithSelection from "discourse/tests/helpers/d-editor-helper";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import { paste, queryAll } from "discourse/tests/helpers/qunit-helpers";
import {
  getTextareaSelection,
  setTextareaSelection,
} from "discourse/tests/helpers/textarea-selection-helper";
import { i18n } from "discourse-i18n";
import DMenus from "float-kit/components/d-menus";

module("Integration | Component | d-editor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis/search-aliases.json", () => {
      return response([]);
    });
  });

  test("preview updates with markdown", async function (assert) {
    const self = this;

    await render(<template><DEditor @value={{self.value}} /></template>);

    assert.dom(".d-editor-button-bar").exists();
    await fillIn(".d-editor-input", "hello **world**");

    assert.strictEqual(this.value, "hello **world**");
    assert
      .dom(".d-editor-preview")
      .hasHtml("<p>hello <strong>world</strong></p>");
  });

  test("links in preview are not tabbable", async function (assert) {
    const self = this;

    await render(<template><DEditor @value={{self.value}} /></template>);

    await fillIn(".d-editor-input", "[discourse](https://www.discourse.org)");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        '<p><a href="https://www.discourse.org" tabindex="-1">discourse</a></p>'
      );
  });

  test("updating the value refreshes the preview", async function (assert) {
    const self = this;

    this.set("value", "evil trout");

    await render(<template><DEditor @value={{self.value}} /></template>);

    assert.dom(".d-editor-preview").hasHtml("<p>evil trout</p>");

    this.set("value", "zogstrip");
    await settled();

    assert.dom(".d-editor-preview").hasHtml("<p>zogstrip</p>");
  });

  function jumpEnd(textarea) {
    if (typeof textarea === "string") {
      textarea = find(textarea);
    }

    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;
    return textarea;
  }

  function testCase(title, testFunc, userOptions = {}) {
    test(title, async function (assert) {
      const self = this;

      this.currentUser.user_option = Object.assign(
        {},
        this.currentUser.user_option,
        userOptions
      );
      this.set("value", "hello world.");

      await render(<template><DEditor @value={{self.value}} /></template>);

      const textarea = jumpEnd("textarea.d-editor-input");
      await testFunc.call(this, assert, textarea);
    });
  }

  function composerTestCase(title, testFunc) {
    test(title, async function (assert) {
      const self = this;

      this.set("value", "hello world.");

      await render(
        <template>
          <DEditor @value={{self.value}} @composerEvents={{true}} />
        </template>
      );

      const textarea = jumpEnd("textarea.d-editor-input");
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

    const example = i18n(`composer.bold_text`);
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
      const example = i18n(`composer.italic_text`);
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
    const self = this;

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

    await render(<template><DEditor @value={{self.value}} /></template>);

    const textarea = find("textarea.d-editor-input");
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
    const self = this;

    this.siteSettings.code_formatting_style = "4-spaces-indent";

    await render(<template><DEditor @value={{self.value}} /></template>);

    const textarea = jumpEnd("textarea.d-editor-input");

    await click("button.code");
    assert.strictEqual(this.value, `    ${i18n("composer.code_text")}`);

    this.set("value", "first line\n\nsecond line\n\nthird line");

    textarea.selectionStart = 11;
    textarea.selectionEnd = 11;

    await click("button.code");
    assert.strictEqual(
      this.value,
      `first line
    ${i18n("composer.code_text")}
second line

third line`
    );

    this.set("value", "first line\n\nsecond line\n\nthird line");

    await click("button.code");
    assert.strictEqual(
      this.value,
      `first line

second line

third line\`${i18n("composer.code_title")}\``
    );
    this.set("value", "first line\n\nsecond line\n\nthird line");

    textarea.selectionStart = 5;
    textarea.selectionEnd = 5;

    await click("button.code");
    assert.strictEqual(
      this.value,
      `first\`${i18n("composer.code_title")}\` line

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

  test("code button does not reset undo history", async function (assert) {
    const self = this;

    this.set("value", "existing");

    await render(<template><DEditor @value={{self.value}} /></template>);
    const textarea = find("textarea.d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = 8;

    await click("button.code");
    assert.strictEqual(this.value, "`existing`");

    await click("button.code");
    assert.strictEqual(this.value, "existing");

    document.execCommand("undo");
    assert.strictEqual(this.value, "`existing`");
    document.execCommand("undo");
    assert.strictEqual(this.value, "existing");
  });

  test("code fences", async function (assert) {
    const self = this;

    this.set("value", "");

    await render(<template><DEditor @value={{self.value}} /></template>);

    const textarea = jumpEnd("textarea.d-editor-input");

    await click("button.code");
    assert.strictEqual(
      this.value,
      `\`\`\`
${i18n("composer.paste_code_text")}
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
      `\`${i18n("composer.code_title")}\`first line
second line
third line`
    );

    assert.strictEqual(textarea.selectionStart, 1);
    assert.strictEqual(
      textarea.selectionEnd,
      i18n("composer.code_title").length + 1
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
    const self = this;

    this.set("value", "one\n\ntwo\n\nthree");

    await render(
      <template>
        <DEditor @value={{self.value}} @composerEvents={{true}} />
      </template>
    );

    const textarea = jumpEnd("textarea.d-editor-input");

    textarea.selectionStart = 0;

    await click("button.blockquote");

    assert.strictEqual(this.value, "> one\n> \n> two\n> \n> three");
    assert.strictEqual(textarea.selectionStart, 0);
    assert.strictEqual(textarea.selectionEnd, 25);

    await click("button.blockquote");
    assert.strictEqual(this.value, "one\n\ntwo\n\nthree");
  });

  test("quote button - selecting empty lines", async function (assert) {
    const self = this;

    this.set("value", "one\n\n\n\ntwo");

    await render(
      <template>
        <DEditor @value={{self.value}} @composerEvents={{true}} />
      </template>
    );

    const textarea = jumpEnd("textarea.d-editor-input");

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
    "unordered list button with no selection",
    async function (assert, textarea) {
      const example = i18n("composer.list_item");

      await click(`button.bullet`);
      assert.strictEqual(this.value, `hello world.\n\n* ${example}`);
      assert.strictEqual(textarea.selectionStart, 14);
      assert.strictEqual(textarea.selectionEnd, 16 + example.length);

      await click(`button.bullet`);
      assert.strictEqual(this.value, `hello world.\n\n${example}`);
    }
  );

  testCase(
    "unordered list button with a selection",
    async function (assert, textarea) {
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
    }
  );

  testCase(
    "unordered list button with a multiple line selection",
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

  testCase(
    "ordered list button with no selection",
    async function (assert, textarea) {
      const example = i18n("composer.list_item");

      await click(`button.list`);
      assert.strictEqual(this.value, `hello world.\n\n1. ${example}`);
      assert.strictEqual(textarea.selectionStart, 14);
      assert.strictEqual(textarea.selectionEnd, 17 + example.length);

      await click(`button.list`);
      assert.strictEqual(this.value, `hello world.\n\n${example}`);
      assert.strictEqual(textarea.selectionStart, 14);
      assert.strictEqual(textarea.selectionEnd, 14 + example.length);
    }
  );

  testCase(
    "ordered list button with a selection",
    async function (assert, textarea) {
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
    }
  );

  testCase(
    "ordered list button with line sequence",
    async function (assert, textarea) {
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
    }
  );

  testCase(
    "ordered list button does not reset undo history",
    async function (assert, textarea) {
      this.set("value", "existing");
      textarea.selectionStart = 0;
      textarea.selectionEnd = 8;

      await click("button.list");
      assert.strictEqual(this.value, "1. existing");

      document.execCommand("undo");

      assert.strictEqual(this.value, "existing");
    }
  );

  testCase(
    "heading button with no selection",
    async function (assert, textarea) {
      this.set("value", "");
      textarea.selectionStart = 0;
      textarea.selectionEnd = 0;

      await click("button.heading");
      await click('.btn[data-name="heading-2"]');

      assert.strictEqual(
        this.value,
        "## Heading",
        "it adds a placeholder and selects it"
      );
      assert.strictEqual(textarea.selectionStart, 3);
      assert.strictEqual(textarea.selectionEnd, 10);
    }
  );

  testCase(
    "heading button with a selection",
    async function (assert, textarea) {
      this.set("value", "Hello world");
      textarea.selectionStart = 0;
      textarea.selectionEnd = 11;

      await click("button.heading");
      await click('.btn[data-name="heading-2"]');

      assert.strictEqual(
        this.value,
        "## Hello world",
        "it applies heading 2 and selects the text"
      );
      assert.strictEqual(textarea.selectionStart, 3);
      assert.strictEqual(textarea.selectionEnd, 14);
    }
  );

  testCase(
    "heading button with a selection and existing heading",
    async function (assert, textarea) {
      this.set("value", "## Hello world");
      textarea.selectionStart = 0;
      textarea.selectionEnd = 14;

      await click("button.heading");
      await click('.btn[data-name="heading-4"]');

      assert.strictEqual(
        this.value,
        "#### Hello world",
        "it applies heading 4 and selects the text"
      );
      assert.strictEqual(textarea.selectionStart, 5);
      assert.strictEqual(textarea.selectionEnd, 16);
    }
  );

  testCase(
    "heading button with a selection and existing heading converting to paragraph",
    async function (assert, textarea) {
      this.set("value", "## Hello world");
      textarea.selectionStart = 0;
      textarea.selectionEnd = 14;

      await click("button.heading");
      await click('.btn[data-name="heading-paragraph"]');

      assert.strictEqual(
        this.value,
        "Hello world",
        "it applies paragraph and selects the text"
      );
      assert.strictEqual(textarea.selectionStart, 0);
      assert.strictEqual(textarea.selectionEnd, 11);
    }
  );

  test("clicking the toggle-direction changes dir from ltr to rtl and back", async function (assert) {
    const self = this;

    this.siteSettings.support_mixed_text_direction = true;
    this.siteSettings.default_locale = "en";

    await render(<template><DEditor @value={{self.value}} /></template>);

    await click("button.toggle-direction");
    assert.dom("textarea.d-editor-input").hasAttribute("dir", "rtl");

    await click("button.toggle-direction");
    assert.dom("textarea.d-editor-input").hasAttribute("dir", "ltr");
  });

  test("toolbar event supports replaceText", async function (assert) {
    const self = this;

    withPluginApi((api) => {
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

    await render(<template><DEditor @value={{self.value}} /></template>);
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
    const self = this;

    this.set("value", "hello world.");
    // we need DMenus here, as we are testing the d-editor which is not renderining
    // the in-element outlet container necessary for DMenu to work
    await render(
      <template><DMenus /><DEditor @value={{self.value}} /></template>
    );
    const picker = emojiPicker();
    jumpEnd("textarea.d-editor-input");
    await click(".d-editor-button-bar .emoji");
    await picker.select("raised_hands");

    assert.strictEqual(
      this.value,
      "hello world. :raised_hands:",
      "it works when there is no partial emoji"
    );

    await click("textarea.d-editor-input");
    await fillIn(".d-editor-input", "starting to type an emoji like :woman");
    jumpEnd("textarea.d-editor-input");
    await triggerKeyEvent(".d-editor-input", "keyup", "Backspace"); //simplest way to trigger more menu here
    await click(".ac-emoji li:last-child a");
    await picker.select("woman_genie");

    assert.strictEqual(
      this.value,
      "starting to type an emoji like :woman_genie:",
      "it works when there is a partial emoji"
    );
  });

  test("Toolbar buttons are only rendered when condition is met", async function (assert) {
    withPluginApi((api) => {
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

    await render(<template><DEditor /></template>);

    assert.dom(".d-editor-button-bar button.shown").exists();
    assert.dom(".d-editor-button-bar button.not-shown").doesNotExist();
  });

  testCase(
    "toolbar buttons tabindex when not using rich_editor",
    async function (assert) {
      this.siteSettings.rich_editor = false;
      await render(<template><DEditor /></template>);
      const buttons = queryAll(".d-editor-button-bar .btn");

      assert
        .dom(buttons[0])
        .hasAttribute("tabindex", "0", "it makes the first button focusable");
      assert.dom(buttons[1]).hasAttribute("tabindex", "-1");
    }
  );

  testCase(
    "toolbar buttons tabindex when using rich_editor",
    async function (assert) {
      this.siteSettings.rich_editor = true;
      await render(<template><DEditor /></template>);
      const buttons = queryAll(".d-editor-button-bar .btn");

      assert
        .dom(buttons[0])
        .hasAttribute(
          "tabindex",
          "-1",
          "it does not make the first button focusable"
        );
    }
  );

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
    const self = this;

    this.set("value", "");
    this.siteSettings.enable_rich_text_paste = true;

    await render(
      <template>
        <DEditor @value={{self.value}} @composerEvents={{true}} />
      </template>
    );

    await paste(".d-editor", "\ta\tb\n1\t2\t3");
    assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2|3|\n");

    document.execCommand("undo");
    assert.strictEqual(this.value, "");
  });

  test("paste a different table", async function (assert) {
    const self = this;

    this.set("value", "");
    this.siteSettings.enable_rich_text_paste = true;

    await render(
      <template>
        <DEditor @value={{self.value}} @composerEvents={{true}} />
      </template>
    );

    await paste(".d-editor", '\ta\tb\n1\t"2\n2.5"\t3');
    assert.strictEqual(this.value, "||a|b|\n|---|---|---|\n|1|2<br>2.5|3|\n");
  });

  testCase(
    `pasting a link into a selection applies a link format`,
    async function (assert, textarea) {
      this.set("value", "See discourse in action");
      setTextareaSelection(textarea, 4, 13);
      const event = await paste(".d-editor", "https://www.discourse.org/");
      assert.strictEqual(
        this.value,
        "See [discourse](https://www.discourse.org/) in action"
      );
      assert.true(event.defaultPrevented);

      document.execCommand("undo");
      assert.strictEqual(this.value, "See discourse in action");
    }
  );

  testCase(
    `pasting other text into a selection will replace text value`,
    async function (assert, textarea) {
      this.set("value", "good morning");
      setTextareaSelection(textarea, 5, 12);
      const event = await paste(".d-editor", "evening");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "good morning");
      assert.false(event.defaultPrevented);
    }
  );

  testCase(
    `pasting a url without a selection will insert the url`,
    async function (assert, textarea) {
      this.set("value", "a link example:");
      jumpEnd(textarea);
      const event = await paste(".d-editor", "https://www.discourse.org/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "a link example:");
      assert.false(event.defaultPrevented);
    }
  );

  testCase(
    `pasting text that contains urls and other content will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "a link example:");
      setTextareaSelection(textarea, 0, 1);
      const event = await paste(
        ".d-editor",
        "Try out Discourse at: https://www.discourse.org/"
      );
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "a link example:");
      assert.false(event.defaultPrevented);
    }
  );

  testCase(
    `pasting an email into a selection applies a link format`,
    async function (assert, textarea) {
      this.set("value", "team email");
      setTextareaSelection(textarea, 5, 10);
      const event = await paste(".d-editor", "mailto:team@discourse.org");
      assert.strictEqual(this.value, "team [email](mailto:team@discourse.org)");
      assert.true(event.defaultPrevented);
    }
  );

  testCase(
    `pasting a url onto a selection that contains urls and other content will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "Try https://www.discourse.org");
      setTextareaSelection(textarea, 0, 29);
      const event = await paste(".d-editor", "https://www.discourse.com/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "Try https://www.discourse.org");
      assert.false(event.defaultPrevented);
    }
  );

  testCase(
    `pasting a url onto a selection that contains bbcode-like tags will use default paste behavior`,
    async function (assert, textarea) {
      this.set("value", "hello [url=foobar]foobar[/url]");
      setTextareaSelection(textarea, 0, 30);
      const event = await paste(".d-editor", "https://www.discourse.com/");
      // Synthetic paste events do not manipulate document content.
      assert.strictEqual(this.value, "hello [url=foobar]foobar[/url]");
      assert.false(event.defaultPrevented);
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
    "smart lists - when enable_smart_lists is false pressing enter on a line with a list item starting with *",
    async function (assert, textarea) {
      const initialValue = "* first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);

      assert.strictEqual(
        this.value,
        initialValue,
        "it does not create an empty list item on the next line"
      );
    },
    { enable_smart_lists: false }
  );

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
    },
    { enable_smart_lists: true }
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
        "doesn't continue the list"
      );
    },
    { enable_smart_lists: true }
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
    },
    { enable_smart_lists: true }
  );

  testCase(
    "smart lists - pressing enter on a line with a list item starting with - creates a list item on the next line",
    async function (assert, textarea) {
      const initialValue = "- first item in list\n";
      this.set("value", initialValue);
      setCaretPosition(textarea, initialValue.length);
      await triggerEnter(textarea);
      assert.strictEqual(this.value, initialValue + "- ");
    },
    { enable_smart_lists: true }
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
    },
    { enable_smart_lists: true }
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
    },
    { enable_smart_lists: true }
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
    },
    { enable_smart_lists: true }
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
    },
    { enable_smart_lists: true }
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

  test("toolbar instance replacement", async function (assert) {
    const self = this;

    const customToolbar = new ToolbarBase({
      siteSettings: this.siteSettings,
      capabilities: this.capabilities,
      showLink: true,
    });
    customToolbar.addButton({
      id: "custom-toolbar-button",
      icon: "plus",
      title: "Custom Toolbar Button",
    });

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "replace-toolbar",
          icon: "xmark",
          group: "extras",
          action: () => {
            toolbar.context.replaceToolbar(customToolbar);
          },
          condition: () => true,
        });
      });
    });

    this.value = "hello";

    await render(<template><DEditor @value={{self.value}} /></template>);

    assert.dom(".d-editor-button-bar").exists();
    assert.dom(".d-editor-button-bar.--replaced-toolbar").doesNotExist();

    await click("button.replace-toolbar");

    assert
      .dom(
        ".d-editor-button-bar.--replaced-toolbar button.custom-toolbar-button"
      )
      .exists("It should show the custom toolbar button");

    // Back button
    await click(".d-editor-button-bar__back");

    assert.dom(".d-editor-button-bar").exists();
    assert.dom(".d-editor-button-bar.--replaced-toolbar").doesNotExist();
  });

  test("popup menu buttons don't break navigation", async function (assert) {
    await render(<template><DEditor /></template>);

    const headingButton = find(".d-editor-button-bar .heading");

    if (headingButton) {
      await focus(headingButton);

      await triggerKeyEvent(headingButton, "keydown", 39); // 39 = ArrowRight

      assert.true(
        true,
        "Navigation from popup menu buttons should not cause errors"
      );
    }
  });
});

module("Integration | Component | d-editor | rich editor", function (hooks) {
  setupRenderingTest(hooks);

  test("replaceText escapes markdown symbols that could be regexp symbols", async function (assert) {
    this.siteSettings.rich_editor = true;

    const initialValue = "Hello\n\n* world\n* am am here $";

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "replace-text",
          icon: "xmark",
          group: "extras",
          action: () => {
            toolbar.context
              .newToolbarEvent()
              .replaceText(initialValue, "goodbye");
          },
          condition: () => true,
        });
      });
    });

    await render(<template><DEditor @value={{initialValue}} /></template>);
    await click(".composer-toggle-switch");
    await click("button.replace-text");

    assert.dom(".ProseMirror p").hasText("goodbye");
  });
});
