export function serializeTags(tags) {
  return tags.map((t) => {
    if (typeof t === "string") {
      return { name: t };
    }
    const numId = Number(t.id);
    if (Number.isInteger(numId) && numId > 0) {
      return { id: numId, name: t.name };
    }
    return { name: t.name };
  });
}
