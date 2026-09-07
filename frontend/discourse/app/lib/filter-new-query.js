const NEW_VALUES = new Map([
  ["new", "all"],
  ["new-topics", "topics"],
  ["new-replies", "replies"],
]);

export function parseFilterNewQuery(query = "") {
  const selections = new Set();
  const tokens =
    query.match(/[\w-]+:(?:"[^"]*"|'[^']*')|"[^"]*"|'[^']*'|\S+/g) || [];
  const baseQuery = tokens
    .map((token) => {
      const match = token.match(/^in:(.*)$/);
      if (!match) {
        return token;
      }

      const value = match[1];
      const remaining = value.split(",").filter((part) => {
        if (NEW_VALUES.has(part)) {
          selections.add(NEW_VALUES.get(part));
          return false;
        }
        return true;
      });

      if (remaining.length === value.split(",").length) {
        return token;
      }
      return remaining.length ? `in:${remaining.join(",")}` : "";
    })
    .filter(Boolean)
    .join(" ");

  return {
    baseQuery,
    selection: selections.size > 1 ? "mixed" : [...selections][0],
  };
}

export function filterNewQuery(query, selection) {
  const { baseQuery } = parseFilterNewQuery(query);
  const value = [...NEW_VALUES].find(([, subset]) => subset === selection)?.[0];
  return [baseQuery, value && `in:${value}`].filter(Boolean).join(" ");
}
