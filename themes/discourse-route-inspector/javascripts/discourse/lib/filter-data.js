export function filterData(data, query, isCaseSensitive = false) {
  if (!query) {
    return data;
  }

  if (typeof data !== "object" || data === null) {
    return false;
  }

  return Object.fromEntries(
    Object.entries(data).filter((entry) =>
      filterPair(entry, query, isCaseSensitive)
    )
  );
}

function filterPair([key, value], query, isCaseSensitive = false) {
  if (typeof value !== "string") {
    value = String(value);
  }

  const normalizedQuery = isCaseSensitive ? query : query.toLowerCase();
  const normalizedKey = isCaseSensitive ? key : key.toLowerCase();
  const normalizedValue = isCaseSensitive ? value : value.toLowerCase();

  return (
    normalizedKey.includes(normalizedQuery) ||
    normalizedValue.includes(normalizedQuery)
  );
}
