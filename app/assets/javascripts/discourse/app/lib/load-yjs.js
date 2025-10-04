import { waitForPromise } from "@ember/test-waiters";

/**
 * Dynamically loads the YJS bundle including ProseMirror integration
 * @returns {Promise<{Y: *, Awareness: Function, ySyncPlugin: Function, yCursorPlugin: Function, yUndoPlugin: Function, undo: Function, redo: Function}>} YJS, Awareness, and y-prosemirror modules
 */
export default async function loadYjs() {
  const promise = import("discourse/static/yjs-bundle");
  waitForPromise(promise);
  return await promise;
}
