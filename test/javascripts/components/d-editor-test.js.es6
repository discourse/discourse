import { next } from "@ember/runloop";
import componentTest from "helpers/component-test";
import { withPluginApi } from "discourse/lib/plugin-api";
import formatTextWithSelection from "helpers/d-editor-helper";
import {
  setTextareaSelection,
  getTextareaSelection
} from "helpers/textarea-selection-helper";

moduleForComponent("d-editor", { integration: true });

componentTest("preview updates with markdown", {
  template: "{{d-editor value=value}}",

  async test(assert) {
    assert.ok(find(".d-editor-button-bar").length);
    await fillIn(".d-editor-input", "hello **world**");

    assert.equal(this.value, "hello **world**");
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim(),
      "<p>hello <strong>world</strong></p>"
    );
  }
});

componentTest("preview sanitizes HTML", {
  template: "{{d-editor value=value}}",

  async test(assert) {
    await fillIn(".d-editor-input", `"><svg onload="prompt(/xss/)"></svg>`);
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim(),
      '<p>"&gt;</p>'
    );
  }
});

componentTest("updating the value refreshes the preview", {
  template: "{{d-editor value=value}}",

  beforeEach() {
    this.set("value", "evil trout");
  },

  async test(assert) {
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim(),
      "<p>evil trout</p>"
    );

    await this.set("value", "zogstrip");
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim(),
      "<p>zogstrip</p>"
    );
  }
});

function jumpEnd(textarea) {
  textarea.selectionStart = textarea.value.length;
  textarea.selectionEnd = textarea.value.length;
  return textarea;
}

function testCase(title, testFunc) {
  componentTest(title, {
    template: "{{d-editor value=value}}",
    beforeEach() {
      this.set("value", "hello world.");
    },
    test(assert) {
      const textarea = jumpEnd(find("textarea.d-editor-input")[0]);
      testFunc.call(this, assert, textarea);
    }
  });
}

function composerTestCase(title, testFunc) {
  componentTest(title, {
    template: "{{d-editor value=value composerEvents=true}}",
    beforeEach() {
      this.set("value", "hello world.");
    },
    test(assert) {
      const textarea = jumpEnd(find("textarea.d-editor-input")[0]);
      testFunc.call(this, assert, textarea);
    }
  });
}

testCase(`selecting the space before a word`, async function(assert, textarea) {
  textarea.selectionStart = 5;
  textarea.selectionEnd = 7;

  await click(`button.bold`);

  assert.equal(this.value, `hello **w**orld.`);
  assert.equal(textarea.selectionStart, 8);
  assert.equal(textarea.selectionEnd, 9);
});

testCase(`selecting the space after a word`, async function(assert, textarea) {
  textarea.selectionStart = 0;
  textarea.selectionEnd = 6;

  await click(`button.bold`);

  assert.equal(this.value, `**hello** world.`);
  assert.equal(textarea.selectionStart, 2);
  assert.equal(textarea.selectionEnd, 7);
});

testCase(`bold button with no selection`, async function(assert, textarea) {
  await click(`button.bold`);

  const example = I18n.t(`composer.bold_text`);
  assert.equal(this.value, `hello world.**${example}**`);
  assert.equal(textarea.selectionStart, 14);
  assert.equal(textarea.selectionEnd, 14 + example.length);
});

testCase(`bold button with a selection`, async function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  await click(`button.bold`);
  assert.equal(this.value, `hello **world**.`);
  assert.equal(textarea.selectionStart, 8);
  assert.equal(textarea.selectionEnd, 13);

  await click(`button.bold`);
  assert.equal(this.value, "hello world.");
  assert.equal(textarea.selectionStart, 6);
  assert.equal(textarea.selectionEnd, 11);
});

testCase(`bold with a multiline selection`, async function(assert, textarea) {
  this.set("value", "hello\n\nworld\n\ntest.");

  textarea.selectionStart = 0;
  textarea.selectionEnd = 12;

  await click(`button.bold`);
  assert.equal(this.value, `**hello**\n\n**world**\n\ntest.`);
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 20);

  await click(`button.bold`);
  assert.equal(this.value, `hello\n\nworld\n\ntest.`);
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 12);
});

testCase(`italic button with no selection`, async function(assert, textarea) {
  await click(`button.italic`);
  const example = I18n.t(`composer.italic_text`);
  assert.equal(this.value, `hello world.*${example}*`);

  assert.equal(textarea.selectionStart, 13);
  assert.equal(textarea.selectionEnd, 13 + example.length);
});

testCase(`italic button with a selection`, async function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  await click(`button.italic`);
  assert.equal(this.value, `hello *world*.`);
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 12);

  await click(`button.italic`);
  assert.equal(this.value, "hello world.");
  assert.equal(textarea.selectionStart, 6);
  assert.equal(textarea.selectionEnd, 11);
});

testCase(`italic with a multiline selection`, async function(assert, textarea) {
  this.set("value", "hello\n\nworld\n\ntest.");

  textarea.selectionStart = 0;
  textarea.selectionEnd = 12;

  await click(`button.italic`);
  assert.equal(this.value, `*hello*\n\n*world*\n\ntest.`);
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 16);

  await click(`button.italic`);
  assert.equal(this.value, `hello\n\nworld\n\ntest.`);
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 12);
});

componentTest("advanced code", {
  template: "{{d-editor value=value}}",
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
    const textarea = find("textarea.d-editor-input")[0];
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await click("button.code");
    assert.equal(
      this.value,
      `
    function xyz(x, y, z) {
      if (y === z) {
        return true;
      }
    }
`
    );
  }
});

componentTest("code button", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.siteSettings.code_formatting_style = "4-spaces-indent";
  },

  async test(assert) {
    const textarea = jumpEnd(find("textarea.d-editor-input")[0]);

    await click("button.code");
    assert.equal(this.value, `    ${I18n.t("composer.code_text")}`);

    this.set("value", "first line\n\nsecond line\n\nthird line");

    textarea.selectionStart = 11;
    textarea.selectionEnd = 11;

    await click("button.code");
    assert.equal(
      this.value,
      `first line
    ${I18n.t("composer.code_text")}
second line

third line`
    );

    this.set("value", "first line\n\nsecond line\n\nthird line");

    await click("button.code");
    assert.equal(
      this.value,
      `first line

second line

third line\`${I18n.t("composer.code_title")}\``
    );
    this.set("value", "first line\n\nsecond line\n\nthird line");

    textarea.selectionStart = 5;
    textarea.selectionEnd = 5;

    await click("button.code");
    assert.equal(
      this.value,
      `first\`${I18n.t("composer.code_title")}\` line

second line

third line`
    );
    this.set("value", "first line\n\nsecond line\n\nthird line");

    textarea.selectionStart = 6;
    textarea.selectionEnd = 10;

    await click("button.code");
    assert.equal(this.value, "first `line`\n\nsecond line\n\nthird line");
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 11);

    await click("button.code");
    assert.equal(this.value, "first line\n\nsecond line\n\nthird line");
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 10);

    textarea.selectionStart = 0;
    textarea.selectionEnd = 23;

    await click("button.code");
    assert.equal(this.value, "    first line\n\n    second line\n\nthird line");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 31);

    await click("button.code");
    assert.equal(this.value, "first line\n\nsecond line\n\nthird line");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 23);
  }
});

componentTest("code fences", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.set("value", "");
  },

  async test(assert) {
    const textarea = jumpEnd(find("textarea.d-editor-input")[0]);

    await click("button.code");
    assert.equal(
      this.value,
      `\`\`\`
${I18n.t("composer.paste_code_text")}
\`\`\``
    );

    assert.equal(textarea.selectionStart, 4);
    assert.equal(textarea.selectionEnd, 27);

    this.set("value", "first line\nsecond line\nthird line");

    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await click("button.code");

    assert.equal(
      this.value,
      `\`\`\`
first line
second line
third line
\`\`\`
`
    );

    assert.equal(textarea.selectionStart, textarea.value.length);
    assert.equal(textarea.selectionEnd, textarea.value.length);

    this.set("value", "first line\nsecond line\nthird line");

    textarea.selectionStart = 0;
    textarea.selectionEnd = 0;

    await click("button.code");

    assert.equal(
      this.value,
      `\`${I18n.t("composer.code_title")}\`first line
second line
third line`
    );

    assert.equal(textarea.selectionStart, 1);
    assert.equal(
      textarea.selectionEnd,
      I18n.t("composer.code_title").length + 1
    );

    this.set("value", "first line\nsecond line\nthird line");

    textarea.selectionStart = 0;
    textarea.selectionEnd = 10;

    await click("button.code");

    assert.equal(
      this.value,
      `\`first line\`
second line
third line`
    );

    assert.equal(textarea.selectionStart, 1);
    assert.equal(textarea.selectionEnd, 11);

    this.set("value", "first line\nsecond line\nthird line");

    textarea.selectionStart = 0;
    textarea.selectionEnd = 23;

    await click("button.code");

    assert.equal(
      this.value,
      `\`\`\`
first line
second line
\`\`\`
third line`
    );

    assert.equal(textarea.selectionStart, 30);
    assert.equal(textarea.selectionEnd, 30);

    this.set("value", "first line\nsecond line\nthird line");

    textarea.selectionStart = 6;
    textarea.selectionEnd = 17;

    await click("button.code");

    assert.equal(
      this.value,
      `first \n\`\`\`\nline\nsecond\n\`\`\`\n line\nthird line`
    );

    assert.equal(textarea.selectionStart, 27);
    assert.equal(textarea.selectionEnd, 27);
  }
});

componentTest("quote button - empty lines", {
  template: "{{d-editor value=value composerEvents=true}}",
  beforeEach() {
    this.set("value", "one\n\ntwo\n\nthree");
  },
  async test(assert) {
    const textarea = jumpEnd(find("textarea.d-editor-input")[0]);

    textarea.selectionStart = 0;

    await click("button.quote");

    assert.equal(this.value, "> one\n> \n> two\n> \n> three");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 25);

    await click("button.quote");
    assert.equal(this.value, "one\n\ntwo\n\nthree");
  }
});

componentTest("quote button - selecting empty lines", {
  template: "{{d-editor value=value composerEvents=true}}",
  beforeEach() {
    this.set("value", "one\n\n\n\ntwo");
  },
  async test(assert) {
    const textarea = jumpEnd(find("textarea.d-editor-input")[0]);

    textarea.selectionStart = 6;
    textarea.selectionEnd = 10;

    await click("button.quote");
    assert.equal(this.value, "one\n\n\n> \n> two");
  }
});

testCase("quote button", async function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 9;

  await click("button.quote");
  assert.equal(this.value, "hello\n\n> wor\n\nld.");
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 12);

  await click("button.quote");

  assert.equal(this.value, "hello\n\nwor\n\nld.");
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 10);

  textarea.selectionStart = 15;
  textarea.selectionEnd = 15;

  await click("button.quote");
  assert.equal(this.value, "hello\n\nwor\n\nld.\n\n> Blockquote");
});

testCase(`bullet button with no selection`, async function(assert, textarea) {
  const example = I18n.t("composer.list_item");

  await click(`button.bullet`);
  assert.equal(this.value, `hello world.\n\n* ${example}`);
  assert.equal(textarea.selectionStart, 14);
  assert.equal(textarea.selectionEnd, 16 + example.length);

  await click(`button.bullet`);
  assert.equal(this.value, `hello world.\n\n${example}`);
});

testCase(`bullet button with a selection`, async function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  await click(`button.bullet`);
  assert.equal(this.value, `hello\n\n* world\n\n.`);
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 14);

  await click(`button.bullet`);
  assert.equal(this.value, `hello\n\nworld\n\n.`);
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 12);
});

testCase(`bullet button with a multiple line selection`, async function(
  assert,
  textarea
) {
  this.set("value", "* Hello\n\nWorld\n\nEvil");

  textarea.selectionStart = 0;
  textarea.selectionEnd = 20;

  await click(`button.bullet`);
  assert.equal(this.value, "Hello\n\nWorld\n\nEvil");
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 18);

  await click(`button.bullet`);
  assert.equal(this.value, "* Hello\n\n* World\n\n* Evil");
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 24);
});

testCase(`list button with no selection`, async function(assert, textarea) {
  const example = I18n.t("composer.list_item");

  await click(`button.list`);
  assert.equal(this.value, `hello world.\n\n1. ${example}`);
  assert.equal(textarea.selectionStart, 14);
  assert.equal(textarea.selectionEnd, 17 + example.length);

  await click(`button.list`);
  assert.equal(this.value, `hello world.\n\n${example}`);
  assert.equal(textarea.selectionStart, 14);
  assert.equal(textarea.selectionEnd, 14 + example.length);
});

testCase(`list button with a selection`, async function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  await click(`button.list`);
  assert.equal(this.value, `hello\n\n1. world\n\n.`);
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 15);

  await click(`button.list`);
  assert.equal(this.value, `hello\n\nworld\n\n.`);
  assert.equal(textarea.selectionStart, 7);
  assert.equal(textarea.selectionEnd, 12);
});

testCase(`list button with line sequence`, async function(assert, textarea) {
  this.set("value", "Hello\n\nWorld\n\nEvil");

  textarea.selectionStart = 0;
  textarea.selectionEnd = 18;

  await click(`button.list`);
  assert.equal(this.value, "1. Hello\n\n2. World\n\n3. Evil");
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 27);

  await click(`button.list`);
  assert.equal(this.value, "Hello\n\nWorld\n\nEvil");
  assert.equal(textarea.selectionStart, 0);
  assert.equal(textarea.selectionEnd, 18);
});

componentTest("clicking the toggle-direction button toggles the direction", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.siteSettings.support_mixed_text_direction = true;
    this.siteSettings.default_locale = "en_US";
  },

  async test(assert) {
    const textarea = find("textarea.d-editor-input");
    await click("button.toggle-direction");
    assert.equal(textarea.attr("dir"), "rtl");
    await click("button.toggle-direction");
    assert.equal(textarea.attr("dir"), "ltr");
  }
});

testCase(`doesn't jump to bottom with long text`, async function(
  assert,
  textarea
) {
  let longText = "hello world.";
  for (let i = 0; i < 8; i++) {
    longText = longText + longText;
  }
  this.set("value", longText);

  $(textarea).scrollTop(0);
  textarea.selectionStart = 3;
  textarea.selectionEnd = 3;

  await click("button.bold");
  assert.equal($(textarea).scrollTop(), 0, "it stays scrolled up");
});

componentTest("emoji", {
  skip: true,
  template: "{{d-editor value=value}}",
  beforeEach() {
    // Test adding a custom button
    withPluginApi("0.1", api => {
      api.onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "far-smile",
          action: () => toolbar.context.send("emoji")
        });
      });
    });
    this.set("value", "hello world.");
  },
  async test(assert) {
    jumpEnd(find("textarea.d-editor-input")[0]);
    await click("button.emoji");

    await click(
      '.emoji-picker .section[data-section="smileys_&_emotion"] button.emoji[title="grinning"]'
    );
    assert.equal(this.value, "hello world.:grinning:");
  }
});

testCase("replace-text event by default", async function(assert) {
  this.set("value", "red green blue");

  await this.container
    .lookup("service:app-events")
    .trigger("composer:replace-text", "green", "yellow");

  assert.equal(this.value, "red green blue");
});

composerTestCase("replace-text event for composer", async function(assert) {
  this.set("value", "red green blue");

  await this.container
    .lookup("service:app-events")
    .trigger("composer:replace-text", "green", "yellow");

  assert.equal(this.value, "red yellow blue");
});

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
      after: [0, 0]
    },
    {
      description: "cursor before needle becomes cursor before replacement",
      before: [BEFORE.indexOf(NEEDLE), 0],
      after: [AFTER.indexOf(REPLACE), 0]
    },
    {
      description: "cursor at needle start + 1 moves behind replacement",
      before: [BEFORE.indexOf(NEEDLE) + 1, 0],
      after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0]
    },
    {
      description: "cursor at needle end - 1 stays behind replacement",
      before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length - 1, 0],
      after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0]
    },
    {
      description: "cursor behind needle becomes cursor behind replacement",
      before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length, 0],
      after: [AFTER.indexOf(REPLACE) + REPLACE.length, 0]
    },
    {
      description: "cursor at end remains there",
      before: [BEFORE.length, 0],
      after: [AFTER.length, 0]
    },
    {
      description:
        "selection spanning needle start becomes selection until replacement start",
      before: [BEFORE.indexOf(NEEDLE) - 1, 2],
      after: [AFTER.indexOf(REPLACE) - 1, 1]
    },
    {
      description:
        "selection spanning needle end becomes selection from replacement end",
      before: [BEFORE.indexOf(NEEDLE) + NEEDLE.length - 1, 2],
      after: [AFTER.indexOf(REPLACE) + REPLACE.length, 1]
    },
    {
      description:
        "selection spanning needle becomes selection spanning replacement",
      before: [BEFORE.indexOf(NEEDLE) - 1, NEEDLE.length + 2],
      after: [AFTER.indexOf(REPLACE) - 1, REPLACE.length + 2]
    },
    {
      description: "complete selection remains complete",
      before: [0, BEFORE.length],
      after: [0, AFTER.length]
    }
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
        assert.equal(actual, expect);
      });
    });
  }
})();
