import type { TrustedHTML } from "@ember/template";
import { waitForPromise } from "@ember/test-waiters";
import AllowLister from "pretty-text/allow-lister";
import {
  buildAnimatedEmojiUrl,
  buildEmojiUrl,
  performEmojiUnescape,
} from "pretty-text/emoji";
import { sanitize as textSanitize } from "pretty-text/sanitizer";
import { getURLWithCDN } from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import type { LinkMatcher } from "discourse/lib/link-matcher";
import type SiteSettingsService from "discourse/services/site-settings";
import { i18n } from "discourse-i18n";
import { QUOTATION_MARKS } from "discourse-markdown-it/features/bbcode-block";

export { parseBBCodeTag } from "discourse-markdown-it/features/bbcode-block";

/** Options for the allow list that `sanitize` checks HTML against. */
export interface AllowListOptions {
  /** URL schemes allowed in `href`s, besides the defaults. */
  allowedHrefSchemes?: string[];

  /** Iframe sources that are allowed. */
  allowedIframes?: string[];

  /** The markdown features whose allow lists are enabled. */
  features?: Record<string, boolean>;
}

/** Options for the markdown engine, read by its `buildOptions`. */
export type MarkdownOptions = Record<string, unknown>;

/** Options for rendering emoji, as `emojiOptions` builds them. */
export interface EmojiOptions {
  /** Builds the URL of an emoji image from its path. */
  getURL: (url: string) => string;

  /** The emoji set, such as `"twitter"`. */
  emojiSet: string;

  /** Whether text shortcuts such as `:)` become emoji. */
  enableEmojiShortcuts: boolean;

  /** Whether shortcuts inside words become emoji. */
  inlineEmoji: boolean;

  /** Emoji that are not rendered. */
  emojiDenyList: string[] | undefined;

  /** The external URL emoji images are served from, or `""`. */
  emojiCDNUrl: string;
}

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the settings read here. Remove it once the service types its settings.
 */
interface EmojiSettings {
  enable_emoji: boolean;
  emoji_set: string;
  enable_emoji_shortcuts: boolean;
  enable_inline_emoji_translation: boolean;
  external_emoji_url: string;
}

type MarkdownEngine = typeof import("discourse/static/markdown-it");

async function withEngine<K extends keyof MarkdownEngine>(
  name: K,
  ...args: Parameters<MarkdownEngine[K]>
): Promise<ReturnType<MarkdownEngine[K]>> {
  const engine = await waitForPromise(import("discourse/static/markdown-it"));
  // A member picked by a generic key can't be called with its spread arguments.
  return (
    engine[name] as (
      ...args: Parameters<MarkdownEngine[K]>
    ) => ReturnType<MarkdownEngine[K]>
  )(...args);
}

/**
 * Loads the markdown engine and cooks markdown into HTML.
 *
 * @param text - The markdown.
 * @param options - The engine options.
 * @returns The trusted HTML.
 */
export async function cook(
  text: string | null | undefined,
  options?: MarkdownOptions
): Promise<TrustedHTML> {
  return await withEngine("cook", text, options);
}

/**
 * Warms up the engine with a set of options, and returns a function that cooks
 * without rebuilding the engine every time.
 *
 * @param options - The engine options.
 * @returns A function from markdown to HTML.
 */
export async function generateCookFunction(
  options?: MarkdownOptions
): Promise<(text: string | null | undefined) => string> {
  return await withEngine("generateCookFunction", options);
}

/**
 * Loads the markdown engine and returns its link matcher for `options`.
 *
 * @param options - The engine options.
 * @returns The link matcher.
 */
export async function generateLinkifyFunction(
  options?: MarkdownOptions
): Promise<LinkMatcher> {
  return await withEngine("generateLinkifyFunction", options);
}

// TODO: this one is special, it attempts to do something even without
// the engine loaded. Currently, this is what is forcing the xss library
// to be included on initial page load. The API/behavior also seems a bit
// different than the async version.
/**
 * Removes the HTML that the allow list doesn't allow, without loading the
 * markdown engine.
 *
 * @param text - The HTML.
 * @param options - The allow list options.
 * @returns The sanitized HTML.
 */
export function sanitize(
  text: string | null | undefined,
  options?: AllowListOptions | null
): string {
  return textSanitize(text, new AllowLister(options));
}

/**
 * Loads the markdown engine and removes the HTML its allow list doesn't allow.
 *
 * @param text - The HTML.
 * @param options - The engine options.
 * @returns The sanitized HTML.
 */
export async function sanitizeAsync(
  text: string,
  options?: MarkdownOptions
): Promise<string> {
  return await withEngine("sanitize", text, options);
}

/**
 * Loads the markdown engine and parses markdown into tokens.
 *
 * @param md - The markdown.
 * @param options - The engine options.
 * @param env - The parse environment.
 * @returns The tokens. TODO(typescript-pending): the engine is untyped, so its
 *   tokens are `any`.
 */
export async function parseAsync(
  md: string,
  options: MarkdownOptions = {},
  env: Record<string, unknown> = {}
) {
  return await withEngine("parse", md, options, env);
}

/**
 * Loads the markdown engine and lists the names mentioned in markdown.
 *
 * @param markdown - The markdown.
 * @param options - The engine options.
 * @returns The mentioned names, without duplicates.
 */
export async function parseMentions(
  markdown: string,
  options?: MarkdownOptions
): Promise<string[]> {
  return await withEngine("parseMentions", markdown, options);
}

/**
 * Builds the emoji rendering options from the site settings.
 *
 * @returns The options, or `undefined` while emoji are disabled.
 */
export function emojiOptions(): EmojiOptions | undefined {
  const siteSettings = helperContext().siteSettings as SiteSettingsService &
    EmojiSettings;
  const context = helperContext();
  if (!siteSettings.enable_emoji) {
    return;
  }

  return {
    getURL: (url: string) => getURLWithCDN(url),
    emojiSet: siteSettings.emoji_set,
    enableEmojiShortcuts: siteSettings.enable_emoji_shortcuts,
    inlineEmoji: siteSettings.enable_inline_emoji_translation,
    emojiDenyList: context.site.denied_emojis,
    emojiCDNUrl: siteSettings.external_emoji_url,
  };
}

/**
 * Replaces emoji codes and shortcuts in text with emoji images.
 *
 * @param string - The text.
 * @param options - More rendering options, such as `tabIndex`.
 * @returns The HTML, or the text unchanged while emoji are disabled. Empty
 *   text renders as `undefined` while emoji are enabled.
 */
export function emojiUnescape<T extends string | null | undefined>(
  string: T,
  options?: Record<string, unknown> | null
): T | string | undefined {
  const opts = emojiOptions();
  if (opts) {
    return performEmojiUnescape(string, Object.assign(opts, options || {}));
  } else {
    return string;
  }
}

/**
 * Builds the URL of an emoji image.
 *
 * @param code - The emoji code, such as `"smile"`.
 * @returns The URL, or `undefined` while emoji are disabled.
 */
export function emojiUrlFor(code: string): string | undefined {
  const opts = emojiOptions();
  if (opts) {
    return buildEmojiUrl(code, opts);
  }
}

/**
 * Builds the URL of an animated emoji image.
 *
 * @param code - The emoji code, such as `"smile"`.
 * @returns The URL, or `undefined` when there is none or emoji are disabled.
 */
export function animatedEmojiUrlFor(code: string): string | undefined {
  const opts = emojiOptions();
  if (opts) {
    return buildAnimatedEmojiUrl(code, opts);
  }
}

function encode(str: string): string {
  return str.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

/**
 * Walks a DOM tree, descending into each node the callback returns a truthy
 * value for. The callback receives text nodes too, and checks `nodeType` before
 * it reads element members.
 */
function traverse(element: Node, callback: (element: HTMLElement) => unknown) {
  if (callback(element as HTMLElement)) {
    element.childNodes.forEach((child) => traverse(child, callback));
  }
}

/**
 * Builds a plain excerpt of cooked HTML, keeping links and emoji images.
 *
 * @param cooked - The cooked HTML.
 * @param length - The length of text to keep.
 * @returns The excerpt HTML.
 */
export function excerpt(cooked: string, length: number): string {
  let result = "";
  let resultLength = 0;

  const div = document.createElement("div");
  div.innerHTML = cooked;
  traverse(div, (element) => {
    if (resultLength >= length) {
      return;
    }

    if (element.nodeType === Node.TEXT_NODE) {
      if (resultLength + element.textContent.length > length) {
        const text = element.textContent.slice(0, length - resultLength);
        result += encode(text);
        result += "&hellip;";
        resultLength += text.length;
      } else {
        result += encode(element.textContent);
        resultLength += element.textContent.length;
      }
    } else if (element.tagName === "A") {
      result += element.outerHTML;
      resultLength += element.innerText.length;
    } else if (element.tagName === "IMG") {
      if (element.classList.contains("emoji")) {
        result += element.outerHTML;
      } else {
        result += "[image]";
        resultLength += "[image]".length;
      }
    } else {
      return true;
    }
  });

  return result;
}

/**
 * Joins items into a list such as "a, b and c".
 *
 * @param listItems - The items.
 * @returns The list, or the only item as is.
 */
export function humanizeList<T>(
  listItems: Iterable<T>
): T | string | undefined {
  const items = Array.from(listItems);
  const last = items.pop();

  if (items.length === 0) {
    return last;
  } else {
    return [
      items.join(i18n("word_connector.comma")),
      i18n("word_connector.last_item"),
      last,
    ].join(" ");
  }
}

// Characters that require quoting in BBCode attribute values
// Based on the BBCode parser regex: [^\s\]]+ for unquoted values
const BBCODE_REQUIRES_QUOTES_PATTERN = /[\s\]]/;

/**
 * Serializes a value for use in a BBCode attribute.
 *
 * Automatically determines whether quotes are needed based on the value content.
 * Quotes are required when the value contains whitespace or `]` characters.
 * When the value contains quotation marks, cycles through supported quote pairs
 * to find one that doesn't conflict with the value's content.
 *
 * @param value - The attribute value to serialize
 * @param name - The attribute name
 * @returns The serialized attribute (e.g., ` name=value` or ` name="value"`) or empty string if value is falsy
 *
 * @example
 * ```js
 * serializeBBCodeAttr("12:00:00", "time") // returns ' time=12:00:00'
 * serializeBBCodeAttr("YYYY-MM-DD HH:mm", "format") // returns ' format="YYYY-MM-DD HH:mm"'
 * serializeBBCodeAttr('Design "Gems"', "channel") // returns " channel='Design \"Gems\"'"
 * serializeBBCodeAttr("Sam's \"Release\"", "title") // returns ' title=«Sam's "Release"»'
 * serializeBBCodeAttr(null, "time") // returns ''
 * ```
 */
export function serializeBBCodeAttr(value: unknown, name: string): string {
  if (!value) {
    return "";
  }

  const stringValue = String(value);
  const needsQuotes = BBCODE_REQUIRES_QUOTES_PATTERN.test(stringValue);

  if (!needsQuotes) {
    return ` ${name}=${stringValue}`;
  }

  for (const pair of QUOTATION_MARKS) {
    const [open, close] = pair;
    if (!stringValue.includes(open) && !stringValue.includes(close)) {
      return ` ${name}=${open}${stringValue}${close}`;
    }
  }

  // Unreachable in practice - would require all 18 quote characters in value
  return ` ${name}="${stringValue.replaceAll('"', "")}"`;
}

/**
 * Builds a BBCode attributes string from an object of key-value pairs.
 *
 * @param attrs - Object containing attribute key-value pairs
 * @param opts - Options. `skipAttrs` lists attribute names to skip.
 * @returns The serialized attributes string (e.g., 'name=value foo="bar baz"')
 */
export function buildBBCodeAttrs(
  attrs: Record<string, unknown>,
  opts: { skipAttrs?: string[] } = {}
): string {
  opts.skipAttrs = opts.skipAttrs ?? [];

  return Object.keys(attrs)
    .map((key) => {
      if (
        attrs[key] === null ||
        attrs[key] === undefined ||
        opts.skipAttrs!.includes(key)
      ) {
        return null;
      }
      return serializeBBCodeAttr(attrs[key], key).trim();
    })
    .filter(Boolean)
    .join(" ");
}
