/**
 * Shared regex patterns for block arg schemas. Applied via `pattern:` on a
 * string arg — the block framework's `validateArgValue` enforces them at
 * render time and consumers that validate edits surface the failure.
 */

/**
 * Accepts a relative path (`/categories`), an absolute URL
 * (`https://example.com/foo`), an in-page anchor (`#section`), or a
 * `mailto:` link. Empty strings do not match, which is intentional — args
 * that participate in URL pattern checks drop their `default: ""` so an
 * unset value reaches `validateArgValue` as `undefined` and short-circuits
 * before the regex runs.
 */
export const URL_PATTERN =
  /^(\/[^\s]*|https?:\/\/[^\s]+|#[^\s]+|mailto:[^\s]+)$/i;

/** Hex colors only: `#rgb`, `#rrggbb`, or `#rrggbbaa`. */
export const HEX_COLOR_PATTERN = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

/** Icon-name shape: kebab-case lowercase. */
export const ICON_NAME_PATTERN = /^[a-z0-9-]+$/;
