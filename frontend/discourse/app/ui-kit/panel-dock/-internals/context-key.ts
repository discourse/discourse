/**
 * What a panel's context may be made of.
 *
 * One string has to survive three places at once: a `localStorage` key, a
 * browser window name, and a URL segment. Only the last is restrictive, so the
 * shape is what all three carry unescaped and unambiguously.
 *
 * Kept character-for-character in step with the two server-side copies, in
 * `config/routes.rb` (the route constraint) and `PanelWindowsController#show`.
 * A pattern narrower than the route's would withhold a window the server would
 * happily have served; a wider one would open a popup onto a 404.
 */
const CONTEXT_KEY = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/;

/**
 * Narrows a context to one that can also name a window.
 *
 * Gates the window capability only, never storage. A panel whose context cannot
 * be a URL segment keeps remembering its docked layout under that context
 * exactly as before; it is simply never offered a window it could not open.
 * Dropping a reader's remembered layout because an unrelated rule tightened
 * would be a worse bug than the one the rule prevents.
 *
 * @param value - The context a panel was given, if it was given one.
 * @returns The context when it can name a window, and `null` when it cannot.
 */
export function validContextKey(value: string | undefined): string | null {
  return value !== undefined && CONTEXT_KEY.test(value) ? value : null;
}
