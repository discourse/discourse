export const COLUMN_SORT_PRIORITY = "priority";
export const COLUMN_SORT_RECENCY = "recency";

export function isRecencyColumn(column) {
  return column?.default_sort === COLUMN_SORT_RECENCY;
}

export function cardRecencyValue(card) {
  const value = Date.parse(
    card?.recency_at ||
      card?.column_changed_at ||
      card?.updated_at ||
      card?.topic?.bumped_at ||
      card?.created_at ||
      ""
  );

  return Number.isFinite(value) ? value : 0;
}

export function sortCardsForColumn(column, cards = []) {
  const sorted = [...cards];

  if (isRecencyColumn(column)) {
    return sorted.sort(
      (a, b) =>
        cardRecencyValue(b) - cardRecencyValue(a) || (b.id || 0) - (a.id || 0)
    );
  }

  return sorted.sort(
    (a, b) => (a.position || 0) - (b.position || 0) || (a.id || 0) - (b.id || 0)
  );
}
