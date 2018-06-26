import componentTest from "helpers/component-test";
import { withPluginApi } from "discourse/lib/plugin-api";

moduleForComponent("d-editor", { integration: true });

componentTest("preview updates with markdown", {
  template: "{{d-editor value=value}}",

  test(assert) {
    assert.ok(this.$(".d-editor-button-bar").length);
    fillIn(".d-editor-input", "hello **world**");

    andThen(() => {
      assert.equal(this.get("value"), "hello **world**");
      assert.equal(
        this.$(".d-editor-preview")
          .html()
          .trim(),
        "<p>hello <strong>world</strong></p>"
      );
    });
  }
});

componentTest("preview sanitizes HTML", {
  template: "{{d-editor value=value}}",

  test(assert) {
    fillIn(".d-editor-input", `"><svg onload="prompt(/xss/)"></svg>`);
    andThen(() => {
      assert.equal(
        this.$(".d-editor-preview")
          .html()
          .trim(),
        '<p>"&gt;</p>'
      );
    });
  }
});

componentTest("updating the value refreshes the preview", {
  template: "{{d-editor value=value}}",

  beforeEach() {
    this.set("value", "evil trout");
  },

  test(assert) {
    assert.equal(
      this.$(".d-editor-preview")
        .html()
        .trim(),
      "<p>evil trout</p>"
    );

    andThen(() => this.set("value", "zogstrip"));
    andThen(() =>
      assert.equal(
        this.$(".d-editor-preview")
          .html()
          .trim(),
        "<p>zogstrip</p>"
      )
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
      const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);
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
      const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);
      testFunc.call(this, assert, textarea);
    }
  });
}

testCase(`selecting the space before a word`, function(assert, textarea) {
  textarea.selectionStart = 5;
  textarea.selectionEnd = 7;

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), `hello **w**orld.`);
    assert.equal(textarea.selectionStart, 8);
    assert.equal(textarea.selectionEnd, 9);
  });
});

testCase(`selecting the space after a word`, function(assert, textarea) {
  textarea.selectionStart = 0;
  textarea.selectionEnd = 6;

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), `**hello** world.`);
    assert.equal(textarea.selectionStart, 2);
    assert.equal(textarea.selectionEnd, 7);
  });
});

testCase(`bold button with no selection`, function(assert, textarea) {
  click(`button.bold`);
  andThen(() => {
    const example = I18n.t(`composer.bold_text`);
    assert.equal(this.get("value"), `hello world.**${example}**`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 14 + example.length);
  });
});

testCase(`bold button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), `hello **world**.`);
    assert.equal(textarea.selectionStart, 8);
    assert.equal(textarea.selectionEnd, 13);
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), "hello world.");
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 11);
  });
});

testCase(`bold with a multiline selection`, function(assert, textarea) {
  this.set("value", "hello\n\nworld\n\ntest.");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 12;
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), `**hello**\n\n**world**\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 20);
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\nworld\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`italic button with no selection`, function(assert, textarea) {
  click(`button.italic`);
  andThen(() => {
    const example = I18n.t(`composer.italic_text`);
    assert.equal(this.get("value"), `hello world._${example}_`);

    assert.equal(textarea.selectionStart, 13);
    assert.equal(textarea.selectionEnd, 13 + example.length);
  });
});

testCase(`italic button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get("value"), `hello _world_.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get("value"), "hello world.");
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 11);
  });
});

testCase(`italic with a multiline selection`, function(assert, textarea) {
  this.set("value", "hello\n\nworld\n\ntest.");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 12;
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get("value"), `_hello_\n\n_world_\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 16);
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\nworld\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase("link modal (cancel)", function(assert) {
  assert.equal(this.$(".insert-link.hidden").length, 1);

  click("button.link");
  andThen(() => {
    assert.equal(this.$(".insert-link.hidden").length, 0);
  });

  click(".insert-link button.btn-danger");
  andThen(() => {
    assert.equal(this.$(".insert-link.hidden").length, 1);
    assert.equal(this.get("value"), "hello world.");
  });
});

testCase("link modal (simple link)", function(assert, textarea) {
  click("button.link");

  const url = "http://eviltrout.com";

  fillIn(".insert-link input.link-url", url);
  click(".insert-link button.btn-primary");
  andThen(() => {
    assert.equal(this.$(".insert-link.hidden").length, 1);
    assert.equal(this.get("value"), `hello world.[${url}](${url})`);
    assert.equal(textarea.selectionStart, 13);
    assert.equal(textarea.selectionEnd, 13 + url.length);
  });
});

testCase("link modal auto http addition", function(assert) {
  click("button.link");
  fillIn(".insert-link input.link-url", "sam.com");
  click(".insert-link button.btn-primary");
  andThen(() => {
    assert.equal(this.get("value"), `hello world.[sam.com](http://sam.com)`);
  });
});

testCase("link modal (simple link) with selected text", function(
  assert,
  textarea
) {
  textarea.selectionStart = 0;
  textarea.selectionEnd = 12;

  click("button.link");
  andThen(() => {
    assert.equal(this.$("input.link-text")[0].value, "hello world.");
  });
  fillIn(".insert-link input.link-url", "http://eviltrout.com");
  click(".insert-link button.btn-primary");
  andThen(() => {
    assert.equal(this.$(".insert-link.hidden").length, 1);
    assert.equal(this.get("value"), "[hello world.](http://eviltrout.com)");
  });
});

testCase("link modal (link with description)", function(assert) {
  click("button.link");
  fillIn(".insert-link input.link-url", "http://eviltrout.com");
  fillIn(".insert-link input.link-text", "evil trout");
  click(".insert-link button.btn-primary");
  andThen(() => {
    assert.equal(this.$(".insert-link.hidden").length, 1);
    assert.equal(
      this.get("value"),
      "hello world.[evil trout](http://eviltrout.com)"
    );
  });
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

  test(assert) {
    const textarea = this.$("textarea.d-editor-input")[0];
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `
    function xyz(x, y, z) {
      if (y === z) {
        return true;
      }
    }
`
      );
    });
  }
});

componentTest("code button", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.siteSettings.code_formatting_style = "4-spaces-indent";
  },

  test(assert) {
    const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);

    click("button.code");
    andThen(() => {
      assert.equal(this.get("value"), `    ${I18n.t("composer.code_text")}`);

      this.set("value", "first line\n\nsecond line\n\nthird line");

      textarea.selectionStart = 11;
      textarea.selectionEnd = 11;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `first line
    ${I18n.t("composer.code_text")}
second line

third line`
      );

      this.set("value", "first line\n\nsecond line\n\nthird line");
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `first line

second line

third line\`${I18n.t("composer.code_title")}\``
      );
      this.set("value", "first line\n\nsecond line\n\nthird line");
    });

    andThen(() => {
      textarea.selectionStart = 5;
      textarea.selectionEnd = 5;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `first\`${I18n.t("composer.code_title")}\` line

second line

third line`
      );
      this.set("value", "first line\n\nsecond line\n\nthird line");
    });

    andThen(() => {
      textarea.selectionStart = 6;
      textarea.selectionEnd = 10;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        "first `line`\n\nsecond line\n\nthird line"
      );
      assert.equal(textarea.selectionStart, 7);
      assert.equal(textarea.selectionEnd, 11);
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        "first line\n\nsecond line\n\nthird line"
      );
      assert.equal(textarea.selectionStart, 6);
      assert.equal(textarea.selectionEnd, 10);

      textarea.selectionStart = 0;
      textarea.selectionEnd = 23;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        "    first line\n\n    second line\n\nthird line"
      );
      assert.equal(textarea.selectionStart, 0);
      assert.equal(textarea.selectionEnd, 31);
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        "first line\n\nsecond line\n\nthird line"
      );
      assert.equal(textarea.selectionStart, 0);
      assert.equal(textarea.selectionEnd, 23);
    });
  }
});

componentTest("code fences", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.set("value", "");
  },

  test(assert) {
    const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `\`\`\`
${I18n.t("composer.paste_code_text")}
\`\`\``
      );

      assert.equal(textarea.selectionStart, 4);
      assert.equal(textarea.selectionEnd, 27);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = textarea.value.length;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
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
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
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
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `\`first line\`
second line
third line`
      );

      assert.equal(textarea.selectionStart, 1);
      assert.equal(textarea.selectionEnd, 11);

      this.set("value", "first line\nsecond line\nthird line");

      textarea.selectionStart = 0;
      textarea.selectionEnd = 23;
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
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
    });

    click("button.code");
    andThen(() => {
      assert.equal(
        this.get("value"),
        `first \n\`\`\`\nline\nsecond\n\`\`\`\n line\nthird line`
      );

      assert.equal(textarea.selectionStart, 27);
      assert.equal(textarea.selectionEnd, 27);
    });
  }
});

componentTest("quote button - empty lines", {
  template: "{{d-editor value=value composerEvents=true}}",
  beforeEach() {
    this.set("value", "one\n\ntwo\n\nthree");
  },
  test(assert) {
    const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);

    andThen(() => {
      textarea.selectionStart = 0;
    });

    click("button.quote");
    andThen(() => {
      assert.equal(this.get("value"), "> one\n> \n> two\n> \n> three");
      assert.equal(textarea.selectionStart, 0);
      assert.equal(textarea.selectionEnd, 25);
    });

    click("button.quote");
    andThen(() => {
      assert.equal(this.get("value"), "one\n\ntwo\n\nthree");
    });
  }
});

componentTest("quote button - selecting empty lines", {
  template: "{{d-editor value=value composerEvents=true}}",
  beforeEach() {
    this.set("value", "one\n\n\n\ntwo");
  },
  test(assert) {
    const textarea = jumpEnd(this.$("textarea.d-editor-input")[0]);

    andThen(() => {
      textarea.selectionStart = 6;
      textarea.selectionEnd = 10;
    });

    click("button.quote");
    andThen(() => {
      assert.equal(this.get("value"), "one\n\n\n> \n> two");
    });
  }
});

testCase("quote button", function(assert, textarea) {
  andThen(() => {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 9;
  });

  click("button.quote");
  andThen(() => {
    assert.equal(this.get("value"), "hello\n\n> wor\n\nld.");
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });

  click("button.quote");

  andThen(() => {
    assert.equal(this.get("value"), "hello\n\nwor\n\nld.");
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 10);
  });

  andThen(() => {
    textarea.selectionStart = 15;
    textarea.selectionEnd = 15;
  });

  click("button.quote");
  andThen(() => {
    assert.equal(this.get("value"), "hello\n\nwor\n\nld.\n\n> Blockquote");
  });
});

testCase(`bullet button with no selection`, function(assert, textarea) {
  const example = I18n.t("composer.list_item");

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), `hello world.\n\n* ${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 16 + example.length);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), `hello world.\n\n${example}`);
  });
});

testCase(`bullet button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\n* world\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 14);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\nworld\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`bullet button with a multiple line selection`, function(
  assert,
  textarea
) {
  this.set("value", "* Hello\n\nWorld\n\nEvil");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 20;
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), "Hello\n\nWorld\n\nEvil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 18);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get("value"), "* Hello\n\n* World\n\n* Evil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 24);
  });
});

testCase(`list button with no selection`, function(assert, textarea) {
  const example = I18n.t("composer.list_item");

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), `hello world.\n\n1. ${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 17 + example.length);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), `hello world.\n\n${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 14 + example.length);
  });
});

testCase(`list button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\n1. world\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 15);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), `hello\n\nworld\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`list button with line sequence`, function(assert, textarea) {
  this.set("value", "Hello\n\nWorld\n\nEvil");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 18;
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), "1. Hello\n\n2. World\n\n3. Evil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 27);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get("value"), "Hello\n\nWorld\n\nEvil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 18);
  });
});

componentTest("clicking the toggle-direction button toggles the direction", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    this.siteSettings.support_mixed_text_direction = true;
    this.siteSettings.default_locale = "en";
  },

  test(assert) {
    const textarea = this.$("textarea.d-editor-input");
    click("button.toggle-direction");
    andThen(() => {
      assert.equal(textarea.attr("dir"), "rtl");
    });
    click("button.toggle-direction");
    andThen(() => {
      assert.equal(textarea.attr("dir"), "ltr");
    });
  }
});

testCase(`doesn't jump to bottom with long text`, function(assert, textarea) {
  let longText = "hello world.";
  for (let i = 0; i < 8; i++) {
    longText = longText + longText;
  }
  this.set("value", longText);

  andThen(() => {
    $(textarea).scrollTop(0);
    textarea.selectionStart = 3;
    textarea.selectionEnd = 3;
  });

  click("button.bold");
  andThen(() => {
    assert.equal($(textarea).scrollTop(), 0, "it stays scrolled up");
  });
});

componentTest("emoji", {
  template: "{{d-editor value=value}}",
  beforeEach() {
    // Test adding a custom button
    withPluginApi("0.1", api => {
      api.onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "smile-o",
          action: "emoji"
        });
      });
    });
    this.set("value", "hello world.");
  },
  test(assert) {
    jumpEnd(this.$("textarea.d-editor-input")[0]);
    click("button.emoji");

    click(
      '.emoji-picker .section[data-section="people"] button.emoji[title="grinning"]'
    );
    andThen(() => {
      assert.equal(this.get("value"), "hello world.:grinning:");
    });
  }
});

testCase("replace-text event by default", function(assert) {
  this.set("value", "red green blue");

  andThen(() => {
    this.container
      .lookup("app-events:main")
      .trigger("composer:replace-text", "green", "yellow");
  });

  andThen(() => {
    assert.equal(this.get("value"), "red green blue");
  });
});

composerTestCase("replace-text event for composer", function(assert) {
  this.set("value", "red green blue");

  andThen(() => {
    this.container
      .lookup("app-events:main")
      .trigger("composer:replace-text", "green", "yellow");
  });

  andThen(() => {
    assert.equal(this.get("value"), "red yellow blue");
  });
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

  function setSelection(textarea, [start, len]) {
    textarea.selectionStart = start;
    textarea.selectionEnd = start + len;
  }

  function getSelection(textarea) {
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    return [start, end - start];
  }

  function formatTextWithSelection(text, [start, len]) {
    return [
      '"',
      text.substr(0, start),
      "<",
      text.substr(start, len),
      ">",
      text.substr(start + len),
      '"'
    ].join("");
  }

  for (let i = 0; i < CASES.length; i++) {
    const CASE = CASES[i];
    composerTestCase(`replace-text event: ${CASE.description}`, function(
      assert,
      textarea
    ) {
      this.set("value", BEFORE);
      setSelection(textarea, CASE.before);
      andThen(() => {
        this.container
          .lookup("app-events:main")
          .trigger("composer:replace-text", "green", "yellow");
      });
      andThen(() => {
        let expect = formatTextWithSelection(AFTER, CASE.after);
        let actual = formatTextWithSelection(
          this.get("value"),
          getSelection(textarea)
        );
        assert.equal(actual, expect);
      });
    });
  }
})();
