import { click, find, triggerKeyEvent } from "@ember/test-helpers";

/**
 * Test helpers for driving a `DReorderableList`.
 *
 * A move is two interactions rather than one — open the row's menu, choose a
 * destination — so every surface that tests reordering would otherwise repeat
 * the same pair. Naming the destination also keeps a test readable when a
 * group adds cross-list entries and the menu's positions shift.
 */

/** The handle for one row: its drag source, cursor item, and menu trigger. */
export function handleSelector(key, root = "") {
  const prefix = root ? `${root} ` : "";
  return `${prefix}[data-reorderable-key="${key}"] .d-reorderable-list__handle`;
}

/**
 * One destination inside an open move menu.
 *
 * @param target - `"top"`, `"up"`, `"down"`, `"bottom"`, or `"list"`.
 */
export function moveItemSelector(target) {
  return `.d-reorderable-list__move-item.--${target}`;
}

/** Opens one row's move menu and leaves it open for inspection. */
export async function openMoveMenu(key, root = "") {
  await click(handleSelector(key, root));
}

/**
 * Moves a row the way a pointer user does. The menu closes itself, so this
 * leaves nothing open behind it.
 *
 * @param key - The row's reorderable key.
 * @param target - The destination to choose.
 * @param root - Optional scope, for a page holding several lists.
 */
export async function moveVia(key, target, root = "") {
  await openMoveMenu(key, root);
  await click(moveItemSelector(target));
}

/** The keyboard accelerator for each destination. */
const CHORD_KEYS = {
  up: "ArrowUp",
  down: "ArrowDown",
  top: "Home",
  bottom: "End",
};

/**
 * Moves a row the way the keyboard accelerator does: Alt with an arrow or
 * Home/End on the focused handle.
 *
 * @param key - The row's reorderable key.
 * @param target - The destination to move to.
 * @param root - Optional scope, for a page holding several lists.
 */
export async function moveViaChord(key, target, root = "") {
  const handle = find(handleSelector(key, root));
  handle.focus();
  await triggerKeyEvent(handle, "keydown", CHORD_KEYS[target], {
    altKey: true,
  });
}
