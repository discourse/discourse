import { trustHTML } from "@ember/template";
import { helperContext } from "discourse/lib/helpers";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import type SiteSettingsService from "discourse/services/site-settings";

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the setting read here. Remove it once the service types its settings.
 */
interface EmojiSettings {
  enable_emoji: boolean;
}

/**
 * Renders an emoji image from its code.
 *
 * @param code - The emoji code, such as `"smile"`.
 * @param options - Options for `emojiUnescape`, such as a `title`.
 * @returns The emoji image, or nothing while emoji are disabled.
 */
export default function dEmoji(
  code: string,
  options?: Record<string, unknown> | null
) {
  // With emoji disabled the code would otherwise leak into the UI as literal
  // `:code:` text.
  if (
    !(helperContext().siteSettings as SiteSettingsService & EmojiSettings)
      .enable_emoji
  ) {
    return;
  }

  const escaped = escapeExpression(`:${code}:`);
  // Only an empty string unescapes to `undefined`.
  return trustHTML(emojiUnescape(escaped, options) as string);
}
