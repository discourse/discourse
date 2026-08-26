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
   * The canonical names joined with `+`, valid as an `aria-keyshortcuts` value:
   * `Meta+Enter` / `Control+Enter`. Undefined when there are no keys, so a
   * template binding omits the attribute rather than emitting an empty one.
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
 * shortcut and announce another.
 *
 * @example
 * ```js
 * const { label, aria } = formatShortcut("mod+b");
 * // Apple:  label "⌘ B",   aria "Meta+B"
 * // Others: label "Ctrl B", aria "Control+B"
 * ```
 */
export function formatShortcut(keys?: string | null): FormattedShortcut {
  const { isApple } = capabilities;
  const parsed = (keys ?? "")
    .split("+")
    .map((token) => token.trim().toLowerCase())
    .filter(Boolean)
    .map((token) => describeKey(canonicalKey(token, isApple), isApple));

  return {
    keys: parsed,
    label: parsed.map((key) => key.label).join(" "),
    aria: parsed.length ? parsed.map((key) => key.key).join("+") : undefined,
  };
}
