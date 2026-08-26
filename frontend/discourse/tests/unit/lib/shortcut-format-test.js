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
        keys: [{ key: "Control", label: ctrl, name: ctrl }],
        label: ctrl,
        aria: "Control",
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
          keys: [{ key: "Control", label: ctrl, name: ctrl }],
          label: ctrl,
          aria: "Control",
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
        keys: [{ key: "Control", label: ctrl, name: ctrl }],
        label: ctrl,
        aria: "Control",
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
          },
          { key: "M", label: "M", name: "M" },
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
          },
          { key: "M", label: "M", name: "M" },
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
          },
          {
            key: "Alt",
            label: "⌥",
            name: i18n("shortcut_modifier_key.option"),
          },
          {
            key: "Shift",
            label: "⇧",
            name: i18n("shortcut_modifier_key.shift"),
          },
        ],
        label: "⌥ ⌥ ⇧",
        aria: "Option+Option+Shift",
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
          { key: "Alt", label: alt, name: alt },
          { key: "Alt", label: alt, name: alt },
          { key: "Shift", label: shift, name: shift },
        ],
        label: `${alt} ${alt} ${shift}`,
        aria: "Alt+Alt+Shift",
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
          },
          {
            key: "Enter",
            label: i18n("shortcut_modifier_key.enter"),
            name: i18n("shortcut_modifier_key.enter"),
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

    assert.deepEqual(
      formatShortcut(
        "enter+return+esc+escape+space+tab+backspace+del+delete+home+end+pageup+pagedown"
      ),
      {
        keys: [
          { key: "Enter", label: enter, name: enter },
          { key: "Enter", label: enter, name: enter },
          { key: "Escape", label: esc, name: esc },
          { key: "Escape", label: esc, name: esc },
          { key: "Space", label: "Space", name: "Space" },
          { key: "Tab", label: "Tab", name: "Tab" },
          { key: "Backspace", label: "Backspace", name: "Backspace" },
          { key: "Delete", label: "Delete", name: "Delete" },
          { key: "Delete", label: "Delete", name: "Delete" },
          { key: "Home", label: "Home", name: "Home" },
          { key: "End", label: "End", name: "End" },
          { key: "PageUp", label: "PageUp", name: "PageUp" },
          { key: "PageDown", label: "PageDown", name: "PageDown" },
        ],
        label: `${enter} ${enter} ${esc} ${esc} Space Tab Backspace Delete Delete Home End PageUp PageDown`,
        aria: "Enter+Enter+Escape+Escape+Space+Tab+Backspace+Delete+Delete+Home+End+PageUp+PageDown",
      },
      "named aliases use canonical key names in input order"
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
          },
          {
            key: "ArrowDown",
            label: "↓",
            name: i18n("shortcut_modifier_key.arrow_down"),
          },
          {
            key: "ArrowLeft",
            label: "←",
            name: i18n("shortcut_modifier_key.arrow_left"),
          },
          {
            key: "ArrowRight",
            label: "→",
            name: i18n("shortcut_modifier_key.arrow_right"),
          },
        ],
        label: "↑ ↓ ← →",
        aria: "ArrowUp+ArrowDown+ArrowLeft+ArrowRight",
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
          },
          {
            key: "ArrowDown",
            label: "↓",
            name: i18n("shortcut_modifier_key.arrow_down"),
          },
          {
            key: "ArrowLeft",
            label: "←",
            name: i18n("shortcut_modifier_key.arrow_left"),
          },
          {
            key: "ArrowRight",
            label: "→",
            name: i18n("shortcut_modifier_key.arrow_right"),
          },
        ],
        label: "↑ ↓ ← →",
        aria: "ArrowUp+ArrowDown+ArrowLeft+ArrowRight",
      },
      "HTML entities map to canonical arrow keys"
    );
  });

  test("returns an empty formatted shortcut for empty inputs", function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    for (const input of [undefined, null, "", "+"]) {
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
          { key: "B", label: "B", name: "B" },
          { key: "/", label: "/", name: "/" },
          { key: "Media", label: "Media", name: "Media" },
        ],
        label: "B / Media",
        aria: "B+Slash+Media",
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
          },
          {
            key: "Meta",
            label: "⌘",
            name: i18n("shortcut_modifier_key.command"),
          },
          { key: ".", label: ".", name: "." },
        ],
        label: "⇧ ⌘ .",
        aria: "Shift+Command+Period",
      },
      "Shift precedes Command, and the announced form names the period"
    );

    sinon.stub(capabilities, "isApple").value(false);

    assert.strictEqual(
      formatShortcut("shift+alt+mod+/").aria,
      "Control+Alt+Shift+Slash",
      "non-Apple order is Control, Alt, Shift"
    );
  });
});
