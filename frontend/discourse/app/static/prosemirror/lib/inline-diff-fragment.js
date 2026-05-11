// @ts-check
// Pure helpers used by the inline-diff extension. Kept in their own module
// so they can be unit-tested without mounting a PM view.

export function sliceIsBlockLevel(fragment) {
  if (!fragment) {
    return false;
  }
  for (let i = 0; i < fragment.childCount; i++) {
    if (!fragment.child(i).isInline) {
      return true;
    }
  }
  return false;
}

// Pure structural ranges (paragraph splits, list-item boundary moves) have
// non-zero PM size but nothing visible; skip those so they don't surface as
// orphan revert buttons.
export function fragmentHasVisibleContent(fragment) {
  if (!fragment || fragment.size === 0) {
    return false;
  }
  let visible = false;
  fragment.descendants((node) => {
    if (visible) {
      return false;
    }
    if (node.isLeaf) {
      visible = true;
      return false;
    }
    return true;
  });
  return visible;
}

// Finds the change in a changeset that corresponds to a revert button's
// stored coordinates. Exact match first; falls back to containment, which
// covers the case where the button's change was merged into a wider one by
// the changeset's `combine` fn between render and click.
export function findChangeByCoords(changes, { fromA, toA, fromB, toB }) {
  if (!changes?.length) {
    return null;
  }
  const exact = changes.find(
    (c) =>
      c.fromA === fromA && c.toA === toA && c.fromB === fromB && c.toB === toB
  );
  if (exact) {
    return exact;
  }
  return (
    changes.find(
      (c) =>
        c.fromA <= fromA && c.toA >= toA && c.fromB <= fromB && c.toB >= toB
    ) ?? null
  );
}
