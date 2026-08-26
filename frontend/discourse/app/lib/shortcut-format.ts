import { capabilities } from "discourse/services/capabilities";
import { i18n } from "discourse-i18n";

/** One key of a formatted shortcut. */
export interface ShortcutKey {
  /**
   * The canonical name, as used by `aria-keyshortcuts` and `KeyboardEvent.key`:
   * `Meta`, `Control`, `Alt`, `Shift`, `Enter`, `ArrowUp`, `B`, `/`.
   */
  key: string;
  /** The drawn text: `⌘` on Apple platforms and `Ctrl` elsewhere, `↑`, `Enter`, `B`. */
  label: string;
  /**
   * The text assistive technology should read for the drawn form. Differs from
   * `label` only when `label` is a glyph, in which case it is the localized
   * spelled-out name (`Command`, `Up arrow`).
   */
  name: string;
}

/** Both forms of one shortcut, derived from a single spelling. */
export interface FormattedShortcut {
  keys: ShortcutKey[];
  /** The drawn labels joined with a space: `⌘ Enter` / `Ctrl Enter`. */
  label: string;
  /**
   * The `aria-keyshortcuts` value: the keys' spoken names joined with `+`, in
   * the user's language, since readers speak the attribute verbatim and the
   * operating system's own menus are read that way (`Command+Shift+Ponto` in
   * Brazilian Portuguese). `Command+Enter` on Apple platforms and `Ctrl+Enter`
   * elsewhere in English. Undefined when there are no keys, so a template
   * binding omits the attribute rather than emitting an empty one.
   */
  aria: string | undefined;
}

type Modifier = "mod" | "Control" | "Alt" | "Shift";

/**
 * Modifier spellings accepted on input. `mod` and its synonyms resolve to the
 * platform's primary modifier; `ctrl` stays a literal Control key everywhere.
 */
const MODIFIER_ALIASES: Record<string, Modifier> = {
  mod: "mod",
  meta: "mod",
  command: "mod",
  cmd: "mod",
  super: "mod",
  win: "mod",
  ctrl: "Control",
  control: "Control",
  alt: "Alt",
  option: "Alt",
  shift: "Shift",
};

/** Non-modifier spellings accepted on input, mapped to their canonical name. */
const NAMED_KEYS: Record<string, string> = {
  enter: "Enter",
  return: "Enter",
  esc: "Escape",
  escape: "Escape",
  space: "Space",
  tab: "Tab",
  backspace: "Backspace",
  del: "Delete",
  delete: "Delete",
  home: "Home",
  end: "End",
  pageup: "PageUp",
  pagedown: "PageDown",
  plus: "+",
  up: "ArrowUp",
  down: "ArrowDown",
  left: "ArrowLeft",
  right: "ArrowRight",
  "&uarr;": "ArrowUp",
  "&darr;": "ArrowDown",
  "&larr;": "ArrowLeft",
  "&rarr;": "ArrowRight",
};

/** Keys drawn as a glyph on every platform, with the i18n key of their spoken name. */
const UNIVERSAL_GLYPHS: Record<string, { label: string; name: string }> = {
  ArrowUp: { label: "↑", name: "shortcut_modifier_key.arrow_up" },
  ArrowDown: { label: "↓", name: "shortcut_modifier_key.arrow_down" },
  ArrowLeft: { label: "←", name: "shortcut_modifier_key.arrow_left" },
  ArrowRight: { label: "→", name: "shortcut_modifier_key.arrow_right" },
};

/** Modifiers drawn as a glyph on Apple platforms only. */
const APPLE_GLYPHS: Record<string, { label: string; name: string }> = {
  Meta: { label: "⌘", name: "shortcut_modifier_key.command" },
  Alt: { label: "⌥", name: "shortcut_modifier_key.option" },
  Control: { label: "⌃", name: "shortcut_modifier_key.control" },
  Shift: { label: "⇧", name: "shortcut_modifier_key.shift" },
};

/**
 * The i18n key of each punctuation key's spoken name. Screen readers apply
 * their punctuation verbosity to `aria-keyshortcuts` and drop a lone `.` or `,`
 * at the default level, so the announced form names the key, in the user's
 * language, the way the operating system's own menus are read.
 */
const SPOKEN_PUNCTUATION: Record<string, string> = {
  ".": "shortcut_modifier_key.period",
  ",": "shortcut_modifier_key.comma",
  "/": "shortcut_modifier_key.slash",
  "\\": "shortcut_modifier_key.backslash",
  "?": "shortcut_modifier_key.question_mark",
  "!": "shortcut_modifier_key.exclamation_mark",
  "#": "shortcut_modifier_key.hash",
  "=": "shortcut_modifier_key.equals",
  "-": "shortcut_modifier_key.minus",
  "+": "shortcut_modifier_key.plus",
  ";": "shortcut_modifier_key.semicolon",
  "'": "shortcut_modifier_key.apostrophe",
  "`": "shortcut_modifier_key.backquote",
  "[": "shortcut_modifier_key.left_bracket",
  "]": "shortcut_modifier_key.right_bracket",
};

/**
 * The order modifiers are listed in, whatever order the binding spells them:
 * Apple's guidelines fix Control, Option, Shift, Command, and the same order
 * matches the usual Ctrl, Alt, Shift elsewhere.
 */
const MODIFIER_ORDER = ["Control", "Alt", "Shift", "Meta"];

/** Keys drawn as a localized word rather than their canonical name. */
const WORD_KEYS: Record<string, string> = {
  Control: "shortcut_modifier_key.ctrl",
  Alt: "shortcut_modifier_key.alt",
  Shift: "shortcut_modifier_key.shift",
  Enter: "shortcut_modifier_key.enter",
  Escape: "shortcut_modifier_key.esc",
};

function canonicalKey(token: string, isApple: boolean): string {
  const modifier = MODIFIER_ALIASES[token];
  if (modifier === "mod") {
    return isApple ? "Meta" : "Control";
  }
  if (modifier) {
    return modifier;
  }

  const named = NAMED_KEYS[token];
  if (named) {
    return named;
  }

  // Only ASCII letters are case-folded: other scripts can expand to several
  // characters under `toUpperCase` (`ß` becomes `SS`), which would no longer
  // name one key.
  if (token.length === 1) {
    return token.replace(/^[a-z]$/, (letter) => letter.toUpperCase());
  }

  return token.replace(/^[a-z]/, (letter) => letter.toUpperCase());
}

function describeKey(key: string, isApple: boolean): ShortcutKey {
  const glyph = UNIVERSAL_GLYPHS[key] ?? (isApple ? APPLE_GLYPHS[key] : null);
  if (glyph) {
    return { key, label: glyph.label, name: i18n(glyph.name) };
  }

  const word = WORD_KEYS[key];
  const label = word ? i18n(word) : key;
  return { key, label, name: label };
}

/**
 * Formats a keyboard shortcut for display and announcement from one spelling.
 *
 * The input uses the same spelling as key bindings: `+`-joined, case-insensitive,
 * with `mod` for the platform's primary modifier (`mod+enter`, `ctrl+alt+f`,
 * `shift+b`, `up`). Both outputs derive from it, so a call site cannot draw one
 * shortcut and announce another. Modifiers come out in the platform's
 * conventional order, so `mod+shift+d` draws `⇧⌘ D` on Apple platforms and
 * `Ctrl Shift D` elsewhere.
 *
 * @example
 * ```js
 * const { label, aria } = formatShortcut("mod+b");
 * // Apple:  label "⌘ B",   aria "Command+B"
 * // Others: label "Ctrl B", aria "Ctrl+B"
 * ```
 */
export function formatShortcut(keys?: string | null): FormattedShortcut {
  const { isApple } = capabilities;
  const canonical = (keys ?? "")
    .split("+")
    .map((token) => token.trim().toLowerCase())
    .filter(Boolean)
    .map((token) => canonicalKey(token, isApple));

  const modifiers = canonical
    .filter((key) => MODIFIER_ORDER.includes(key))
    .sort((a, b) => MODIFIER_ORDER.indexOf(a) - MODIFIER_ORDER.indexOf(b));
  const others = canonical.filter((key) => !MODIFIER_ORDER.includes(key));
  const parsed = [...modifiers, ...others].map((key) =>
    describeKey(key, isApple)
  );

  const announced = parsed.map(({ key, name }) => {
    const punctuation = SPOKEN_PUNCTUATION[key];
    return punctuation ? i18n(punctuation) : name;
  });

  return {
    keys: parsed,
    label: parsed.map((key) => key.label).join(" "),
    aria: parsed.length ? announced.join("+") : undefined,
  };
}
