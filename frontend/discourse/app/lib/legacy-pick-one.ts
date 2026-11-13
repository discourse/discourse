/**
 * Adapts a handler written for a select-kit picker capped at one, which always received
 * arrays, to a single select's value and item, so both branches of a call site write the
 * same thing.
 *
 * TODO (select-kit-replacement-cleanup): Remove with the legacy pickers, once each handler
 * takes the single value directly.
 */
export default function legacyPickOne<V, I>(
  handler: (values: V[], items: I[]) => unknown
): (value: V | null, item?: I | null) => unknown {
  return (value, item) =>
    handler(value == null ? [] : [value], item ? [item] : []);
}
