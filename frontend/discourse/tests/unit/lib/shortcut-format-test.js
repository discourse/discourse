import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { capabilities } from "discourse/services/capabilities";
import { i18n } from "discourse-i18n";

module("Unit | Lib | shortcut-format", function (hooks) {
  setupTest(hooks);

  test("formats mod as Command on Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("mod"),
      {
        keys: [
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
            glyph: true,
          },
        ],
        label: "⌘",
        aria: "Command",
      },
      "mod uses the Apple platform modifier"
    );
  });

  test("formats mod as Control on non-Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const ctrl = i18n("shortcut_modifier_key.ctrl");

    assert.deepEqual(
      formatShortcut("mod"),
      {
        keys: [{ key: "Control", label: ctrl, name: ctrl, glyph: false }],
        label: ctrl,
        aria: ctrl,
      },
      "mod uses the non-Apple platform modifier"
    );
  });

  test("treats every mod alias like mod on Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    for (const alias of ["mod", "meta", "command", "cmd", "super", "win"]) {
      assert.deepEqual(
        formatShortcut(alias),
        {
          keys: [
            {
              key: "Meta",
              label: "⌘",
              name: i18n("shortcut_modifier_key.command"),
              glyph: true,
            },
          ],
          label: "⌘",
          aria: "Command",
        },
        `${alias} resolves to Command`
      );
    }
  });

  test("treats every mod alias like mod on non-Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const ctrl = i18n("shortcut_modifier_key.ctrl");

    for (const alias of ["mod", "meta", "command", "cmd", "super", "win"]) {
      assert.deepEqual(
        formatShortcut(alias),
        {
          keys: [{ key: "Control", label: ctrl, name: ctrl, glyph: false }],
          label: ctrl,
          aria: ctrl,
        },
        `${alias} resolves to Control`
      );
    }
  });

  test("keeps ctrl as Control with a glyph on Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("ctrl"),
      {
        keys: [
          {
            key: "Control",
            label: "⌃",
            name: i18n("shortcut_modifier_key.control"),
            glyph: true,
          },
        ],
        label: "⌃",
        aria: "Control",
      },
      "ctrl remains Control rather than becoming Meta"
    );
  });

  test("keeps ctrl as Control with a localized label on non-Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const ctrl = i18n("shortcut_modifier_key.ctrl");

    assert.deepEqual(
      formatShortcut("ctrl"),
      {
        keys: [{ key: "Control", label: ctrl, name: ctrl, glyph: false }],
        label: ctrl,
        aria: ctrl,
      },
      "the non-glyph Control name exactly matches its label"
    );
  });

  test("distinguishes ctrl+m from mod+m on Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("ctrl+m"),
      {
        keys: [
          {
            key: "Control",
            label: "⌃",
            name: i18n("shortcut_modifier_key.control"),
            glyph: true,
          },
          { key: "M", label: "M", name: "M", glyph: false },
        ],
        label: "⌃ M",
        aria: "Control+M",
      },
      "ctrl+m uses Control"
    );
    assert.deepEqual(
      formatShortcut("mod+m"),
      {
        keys: [
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
            glyph: true,
          },
          { key: "M", label: "M", name: "M", glyph: false },
        ],
        label: "⌘ M",
        aria: "Command+M",
      },
      "mod+m uses Meta"
    );
  });

  test("formats Alt, Option, and Shift on Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("alt+option+shift"),
      {
        keys: [
          {
            key: "Alt",
            label: "⌥",
            name: i18n("shortcut_modifier_key.option"),
            glyph: true,
          },
          {
            key: "Shift",
            label: "⇧",
            name: i18n("shortcut_modifier_key.shift"),
            glyph: true,
          },
        ],
        label: "⌥ ⇧",
        aria: "Option+Shift",
      },
      "Apple modifiers use glyph labels and localized spoken names"
    );
  });

  test("formats Alt, Option, and Shift on non-Apple platforms", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const alt = i18n("shortcut_modifier_key.alt");
    const shift = i18n("shortcut_modifier_key.shift");

    assert.deepEqual(
      formatShortcut("alt+option+shift"),
      {
        keys: [
          { key: "Alt", label: alt, name: alt, glyph: false },
          { key: "Shift", label: shift, name: shift, glyph: false },
        ],
        label: `${alt} ${shift}`,
        aria: `${alt}+${shift}`,
      },
      "non-Apple modifiers are all words"
    );
  });

  test("ignores case and surrounding whitespace", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut(" MOD + Enter "),
      {
        keys: [
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
            glyph: true,
          },
          {
            key: "Enter",
            label: i18n("shortcut_modifier_key.enter"),
            name: i18n("shortcut_modifier_key.enter"),
            glyph: false,
          },
        ],
        label: `⌘ ${i18n("shortcut_modifier_key.enter")}`,
        aria: "Command+Enter",
      },
      "tokens are normalized before formatting"
    );
  });

  test("normalizes named key aliases", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const enter = i18n("shortcut_modifier_key.enter");
    const esc = i18n("shortcut_modifier_key.esc");
    const space = i18n("shortcut_modifier_key.space");
    const tab = i18n("shortcut_modifier_key.tab");
    const backspace = i18n("shortcut_modifier_key.backspace");
    const del = i18n("shortcut_modifier_key.delete");
    const home = i18n("shortcut_modifier_key.home");
    const end = i18n("shortcut_modifier_key.end");
    const pageUp = i18n("shortcut_modifier_key.page_up");
    const pageDown = i18n("shortcut_modifier_key.page_down");

    assert.deepEqual(
      formatShortcut(
        "enter+return+esc+escape+space+tab+backspace+del+delete+home+end+pageup+pagedown"
      ),
      {
        keys: [
          { key: "Enter", label: enter, name: enter, glyph: false },
          { key: "Escape", label: esc, name: esc, glyph: false },
          { key: "Space", label: space, name: space, glyph: false },
          { key: "Tab", label: tab, name: tab, glyph: false },
          {
            key: "Backspace",
            label: backspace,
            name: backspace,
            glyph: false,
          },
          { key: "Delete", label: del, name: del, glyph: false },
          { key: "Home", label: home, name: home, glyph: false },
          { key: "End", label: end, name: end, glyph: false },
          { key: "PageUp", label: pageUp, name: pageUp, glyph: false },
          { key: "PageDown", label: pageDown, name: pageDown, glyph: false },
        ],
        label: `${enter} ${esc} ${space} ${tab} ${backspace} ${del} ${home} ${end} ${pageUp} ${pageDown}`,
        aria: `${enter}+${esc}+${space}+${tab}+${backspace}+${del}+${home}+${end}+${pageUp}+${pageDown}`,
      },
      "named aliases use canonical key names in input order"
    );
  });

  test("normalizes comma to the comma key", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    assert.deepEqual(formatShortcut("mod+comma").keys[1], {
      key: ",",
      label: ",",
      name: i18n("shortcut_modifier_key.comma"),
      glyph: false,
    });
    assert.strictEqual(
      formatShortcut("mod+comma").aria,
      `${i18n("shortcut_modifier_key.ctrl")}+${i18n("shortcut_modifier_key.comma")}`
    );
  });

  test("formats word-form arrow keys as glyphs with spoken names", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    assert.deepEqual(
      formatShortcut("up+down+left+right"),
      {
        keys: [
          {
            key: "ArrowUp",
            label: "↑",
            name: i18n("shortcut_modifier_key.arrow_up"),
            glyph: true,
          },
          {
            key: "ArrowDown",
            label: "↓",
            name: i18n("shortcut_modifier_key.arrow_down"),
            glyph: true,
          },
          {
            key: "ArrowLeft",
            label: "←",
            name: i18n("shortcut_modifier_key.arrow_left"),
            glyph: true,
          },
          {
            key: "ArrowRight",
            label: "→",
            name: i18n("shortcut_modifier_key.arrow_right"),
            glyph: true,
          },
        ],
        label: "↑ ↓ ← →",
        aria: `${i18n("shortcut_modifier_key.arrow_up")}+${i18n("shortcut_modifier_key.arrow_down")}+${i18n("shortcut_modifier_key.arrow_left")}+${i18n("shortcut_modifier_key.arrow_right")}`,
      },
      "arrow glyph labels differ from their localized spoken names"
    );
  });

  test("normalizes HTML entity arrow keys", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("&uarr;+&darr;+&larr;+&rarr;"),
      {
        keys: [
          {
            key: "ArrowUp",
            label: "↑",
            name: i18n("shortcut_modifier_key.arrow_up"),
            glyph: true,
          },
          {
            key: "ArrowDown",
            label: "↓",
            name: i18n("shortcut_modifier_key.arrow_down"),
            glyph: true,
          },
          {
            key: "ArrowLeft",
            label: "←",
            name: i18n("shortcut_modifier_key.arrow_left"),
            glyph: true,
          },
          {
            key: "ArrowRight",
            label: "→",
            name: i18n("shortcut_modifier_key.arrow_right"),
            glyph: true,
          },
        ],
        label: "↑ ↓ ← →",
        aria: `${i18n("shortcut_modifier_key.arrow_up")}+${i18n("shortcut_modifier_key.arrow_down")}+${i18n("shortcut_modifier_key.arrow_left")}+${i18n("shortcut_modifier_key.arrow_right")}`,
      },
      "HTML entities map to canonical arrow keys"
    );
  });

  test("returns an empty formatted shortcut for empty inputs", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    for (const input of [undefined, null, ""]) {
      assert.deepEqual(
        formatShortcut(input),
        { keys: [], label: "", aria: undefined },
        `${String(input)} produces no keys`
      );
    }
  });

  test("uppercases single characters and capitalizes unknown words", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    assert.deepEqual(
      formatShortcut("b+/+MEDIA"),
      {
        keys: [
          { key: "B", label: "B", name: "B", glyph: false },
          {
            key: "/",
            label: "/",
            name: i18n("shortcut_modifier_key.slash"),
            glyph: false,
          },
          { key: "Media", label: "Media", name: "Media", glyph: false },
        ],
        label: "B / Media",
        aria: `B+${i18n("shortcut_modifier_key.slash")}+Media`,
      },
      "non-glyph names exactly match their normalized labels"
    );
  });

  test("orders modifiers by platform convention and spells punctuation when announcing", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    assert.deepEqual(
      formatShortcut("mod+shift+."),
      {
        keys: [
          {
            key: "Shift",
            label: "⇧",
            name: i18n("shortcut_modifier_key.shift"),
            glyph: true,
          },
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
            glyph: true,
          },
          {
            key: ".",
            label: ".",
            name: i18n("shortcut_modifier_key.period"),
            glyph: false,
          },
        ],
        label: "⇧ ⌘ .",
        aria: `${i18n("shortcut_modifier_key.shift")}+${i18n("shortcut_modifier_key.command")}+${i18n("shortcut_modifier_key.period")}`,
      },
      "Shift precedes Command, and the announced form names the period"
    );

    sinon.stub(capabilities, "isApple").value(false);

    assert.strictEqual(
      formatShortcut("shift+alt+mod+/").aria,
      `${i18n("shortcut_modifier_key.ctrl")}+${i18n("shortcut_modifier_key.alt")}+${i18n("shortcut_modifier_key.shift")}+${i18n("shortcut_modifier_key.slash")}`,
      "non-Apple order is Control, Alt, Shift"
    );
  });

  test("edge: parses bare and doubled-separator plus keys", function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    const plus = i18n("shortcut_modifier_key.plus");

    assert.deepEqual(
      formatShortcut("+"),
      {
        keys: [{ key: "+", label: "+", name: plus, glyph: false }],
        label: "+",
        aria: plus,
      },
      "a bare separator names the plus key"
    );
    assert.deepEqual(
      formatShortcut("mod++"),
      {
        keys: [
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
            glyph: true,
          },
          { key: "+", label: "+", name: plus, glyph: false },
        ],
        label: "⌘ +",
        aria: `${i18n("shortcut_modifier_key.command")}+${plus}`,
      },
      "a doubled separator names plus after a modifier"
    );
    assert.deepEqual(
      formatShortcut("shift+plus").keys,
      [
        {
          key: "Shift",
          label: "⇧",
          name: i18n("shortcut_modifier_key.shift"),
          glyph: true,
        },
        { key: "+", label: "+", name: plus, glyph: false },
      ],
      "the named alias also names the plus key"
    );
  });

  test("edge: accepts canonical arrow names", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    for (const [canonical, alias] of [
      ["arrowup", "up"],
      ["arrowdown", "down"],
      ["arrowleft", "left"],
      ["arrowright", "right"],
    ]) {
      assert.deepEqual(
        formatShortcut(canonical),
        formatShortcut(alias),
        `${canonical} behaves like ${alias}`
      );
    }
  });

  test("edge: removes duplicate canonical keys", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    const ctrl = i18n("shortcut_modifier_key.ctrl");
    const expected = {
      keys: [
        { key: "Control", label: ctrl, name: ctrl, glyph: false },
        { key: "A", label: "A", name: "A", glyph: false },
      ],
      label: `${ctrl} A`,
      aria: `${ctrl}+A`,
    };

    assert.deepEqual(
      formatShortcut("ctrl+ctrl+a"),
      expected,
      "an identical token is kept once"
    );
    assert.deepEqual(
      formatShortcut("mod+ctrl+a"),
      expected,
      "different aliases resolving to Control are kept once"
    );
  });

  test("edge: preserves non-ASCII single-character keys", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    for (const character of ["ç", "ß"]) {
      assert.deepEqual(
        formatShortcut(character).keys[0],
        {
          key: character,
          label: character,
          name: character,
          glyph: false,
        },
        `${character} remains one non-glyph key`
      );
    }
  });

  test("edge: gives punctuation localized spoken names", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    for (const [key, name] of [
      ["?", "question_mark"],
      [".", "period"],
      [",", "comma"],
      ["/", "slash"],
    ]) {
      assert.deepEqual(
        formatShortcut(key).keys[0],
        {
          key,
          label: key,
          name: i18n(`shortcut_modifier_key.${name}`),
          glyph: false,
        },
        `${key} has a localized spoken name without being a glyph`
      );
    }
  });
});
