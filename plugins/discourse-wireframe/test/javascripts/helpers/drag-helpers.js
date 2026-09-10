import { triggerEvent } from "@ember/test-helpers";

/**
 * Drives a full PDND drag/drop cycle between a source and a target through the
 * test runner. PDND wraps the native HTML5 drag events, so firing them in
 * sequence exercises the real source → dragover → drop pipeline — including
 * the editor's `containerDropTarget` descriptor + dispatch wiring.
 *
 * The same `DataTransfer` must travel across every event so PDND can correlate
 * them; `clientX` / `clientY` are passed on the hover/drop events so
 * position-sensitive targets (the linear drop resolver) read the cursor.
 * Mirrors core's `frontend/discourse/tests/integration/ui-kit/modifiers/
 * drag-and-drop-test.gjs` helper.
 *
 * @param {{
 *   source: string,
 *   target: string,
 *   clientX?: number,
 *   clientY?: number,
 *   dataTransfer?: DataTransfer,
 * }} options
 * @returns {Promise<void>}
 */
export async function simulateDrag({
  source,
  target,
  clientX,
  clientY,
  dataTransfer = new DataTransfer(),
}) {
  await triggerEvent(source, "dragstart", { dataTransfer });
  await triggerEvent(target, "dragenter", { dataTransfer, clientX, clientY });
  await triggerEvent(target, "dragover", { dataTransfer, clientX, clientY });
  await triggerEvent(target, "drop", { dataTransfer, clientX, clientY });
  await triggerEvent(source, "dragend", { dataTransfer });
}
