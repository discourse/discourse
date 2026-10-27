import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import discourseDebounce from "discourse/lib/debounce";

const SAVE_DELAY = 1000;

function save(user) {
  return user.save(["composition_mode"]);
}

/**
 * The composition mode a toggle switches to from the user's current one.
 *
 * @param {import("discourse/models/user").default} user
 * @returns {number} a `USER_OPTION_COMPOSITION_MODES` value
 */
export function toggledCompositionMode(user) {
  return user.useRichEditor
    ? USER_OPTION_COMPOSITION_MODES.markdown
    : USER_OPTION_COMPOSITION_MODES.rich;
}

/**
 * Applies a composition mode right away and saves it shortly after, so quick
 * back-and-forth toggles from any editor end in a single request.
 *
 * @param {import("discourse/models/user").default} user
 * @param {number} mode a `USER_OPTION_COMPOSITION_MODES` value
 */
export function setCompositionMode(user, mode) {
  user.set("user_option.composition_mode", mode);
  discourseDebounce(user, save, user, SAVE_DELAY);
}
