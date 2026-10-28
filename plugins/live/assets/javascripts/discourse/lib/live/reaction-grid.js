// Mirrors the post reactions picker so both lay a given set out the same way:
// below five cells it's a single row, otherwise it wraps at 5 to 7 columns
// (8 on wider screens), preferring a full or fuller last row.
export function reactionGridColumns(count, { wide = false } = {}) {
  const candidates = wide ? [5, 6, 7, 8] : [5, 6, 7];

  if (count < candidates[0]) {
    return count;
  }

  let columns = candidates[0];
  for (const candidate of candidates) {
    const rest = count % candidate;
    if (rest === 0) {
      return candidate;
    }
    if (rest > count % (candidate - 1)) {
      columns = candidate;
    }
  }
  return columns;
}
