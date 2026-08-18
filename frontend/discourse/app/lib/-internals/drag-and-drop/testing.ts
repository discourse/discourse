/**
 * Test-only: end any drag the underlying library still considers in flight.
 *
 * If a test starts a drag (`dragstart`) but the matching `dragend` / `drop`
 * never reaches the library — e.g. the source element is torn down first, or an
 * assertion throws mid-drag — its global drag state stays active and the next
 * test's `dragstart` is silently ignored. Dispatching a `dragend` lets the
 * lifecycle listener tear the drag down. A no-op when nothing is in flight.
 * Call from the global test teardown.
 */
export function resetDragAndDropForTesting() {
  // The library binds its drag-phase listeners on `window` (capture) only
  // while a drag is active, and both dispatches are no-ops when nothing is in
  // flight.
  //
  // The order is load-bearing. `dragend` clears the target stack before
  // dispatching its cancellation, so no target `onDrop` runs; a bare `drop`
  // takes the cancel path only when no drop target is under the cursor, and with
  // one it dispatches a real drop, running target callbacks during teardown.
  // Sending `dragend` first leaves the following `drop` a no-op, because the
  // listeners are unbound by then.
  //
  // This does not silence everything: the library still dispatches its own
  // `onDrop` to the source and to monitors. A source wrapper deferring its
  // consumer callbacks is what would then schedule them during teardown, and
  // guarding that is its job rather than this function's —
  // `registerDragAndDropSource` cancels the pending task from its own cleanup.
  const make = (type: string) =>
    typeof DragEvent === "function"
      ? new DragEvent(type, { bubbles: true })
      : new Event(type, { bubbles: true });
  for (const type of ["dragend", "drop"]) {
    window.dispatchEvent(make(type));
  }
}
