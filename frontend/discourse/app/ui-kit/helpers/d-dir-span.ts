/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { trustHTML } from "@ember/template";
import { helperContext } from "discourse/lib/helpers";
import { escapeExpression } from "discourse/lib/utilities";
import type SiteSettingsService from "discourse/services/site-settings";

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the setting read here. Remove it once the service types its settings.
 */
interface DirectionSettings {
  support_mixed_text_direction: boolean;
}

function setDir(text: string | null | undefined) {
  let content = text ? text : "";
  let siteSettings = helperContext().siteSettings as SiteSettingsService &
    DirectionSettings;
  const mixed = siteSettings.support_mixed_text_direction;
  return `<span ${mixed ? 'dir="auto"' : ""}>${content}</span>`;
}

/**
 * Wraps a text in a span, with an automatic direction when the site supports
 * mixed text direction.
 *
 * @param str - The text.
 * @param params - The options.
 * @returns The span.
 */
export default function dDirSpan(
  str: string | null | undefined,
  params: {
    /** `"true"` keeps the text as HTML instead of escaping it. */
    htmlSafe?: string;
  } = {}
) {
  let isHtmlSafe = false;
  if (params.htmlSafe) {
    isHtmlSafe = params.htmlSafe === "true";
  }
  let text = isHtmlSafe ? str : escapeExpression(str);
  return trustHTML(setDir(text));
}
