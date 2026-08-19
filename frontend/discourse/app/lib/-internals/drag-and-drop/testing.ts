/**
 * Test-only: ends any drag the underlying library still considers in flight.
 * A no-op when nothing is in flight. Call from the global test teardown.
 *
 * A drag whose `dragend` / `drop` never reached the library (source torn down
 * mid-drag, assertion thrown) leaves its global state active, and the next
 * test's `dragstart` is silently ignored.
 */
export function resetDragAndDropForTesting() {
  // The library listens for `dragend` on `window` (capture) only while a drag
  // is active, and treats it as a cancel that empties the targets first.
  const event =
    typeof DragEvent === "function"
      ? new DragEvent("dragend", { bubbles: true })
      : new Event("dragend", { bubbles: true });
  window.dispatchEvent(event);
}
