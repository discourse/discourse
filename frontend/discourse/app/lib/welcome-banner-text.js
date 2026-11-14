import { prioritizeNameFallback } from "discourse/lib/settings";
import { sanitize } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

const VARIABLE_PATTERN = /%\{(site_name|preferred_display_name)\}/g;

/**
 * Which welcome banner audience a viewer belongs to.
 *
 * @param {Object} [currentUser] - The viewer, or nothing for an anonymous visitor.
 * @returns {"anonymous_members"|"new_members"|"logged_in_members"}
 */
export function welcomeBannerAudience(currentUser) {
  if (!currentUser) {
    return "anonymous_members";
  }
  return currentUser.previous_visit_at ? "logged_in_members" : "new_members";
}

/**
 * The welcome banner headline for the viewer, as HTML.
 *
 * @param {Object} options
 * @param {Object} [options.currentUser] - The viewer.
 * @param {string} [options.siteTitle] - The site's title.
 * @param {string} [options.text] - Author text replacing the translation. It's
 *   escaped, then `%{site_name}` and `%{preferred_display_name}` are filled in.
 * @returns {string}
 */
export function welcomeBannerHeader({ currentUser, siteTitle, text }) {
  if (text) {
    return fillVariables(escapeExpression(text), { currentUser, siteTitle });
  }

  const args = { site_name: siteTitle || "" };
  if (currentUser) {
    args.preferred_display_name = sanitize(displayName(currentUser));
  }
  return i18n(
    `welcome_banner.header.${welcomeBannerAudience(currentUser)}`,
    args
  );
}

/**
 * The welcome banner subheader for the viewer, as HTML, or an empty string.
 *
 * @param {Object} options
 * @param {Object} [options.currentUser] - The viewer.
 * @param {string} [options.siteTitle] - The site's title.
 * @param {string} [options.text] - Author text replacing the translation,
 *   treated like the headline's.
 * @returns {string}
 */
export function welcomeBannerSubheader({ currentUser, siteTitle, text }) {
  if (text) {
    return fillVariables(escapeExpression(text), { currentUser, siteTitle });
  }

  const audience = currentUser ? "logged_in_members" : "anonymous_members";
  return I18n.lookup(`welcome_banner.subheader.${audience}`) || "";
}

function displayName(user) {
  return prioritizeNameFallback(user.name, user.username);
}

function fillVariables(html, { currentUser, siteTitle }) {
  const values = {
    site_name: escapeExpression(siteTitle || ""),
    preferred_display_name: currentUser
      ? escapeExpression(displayName(currentUser))
      : "",
  };
  return html.replace(VARIABLE_PATTERN, (_, name) => values[name]);
}
