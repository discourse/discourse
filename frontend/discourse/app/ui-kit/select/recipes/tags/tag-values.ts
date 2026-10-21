/** A tag held by a consumer, including name-only and newly created tags. */
export interface TagObject {
  id?: number | string | null;
  name: string;
  isNew?: boolean;
}

/** Primitive held values distinguish numeric ids from names, even numeric-looking names. */
export type HeldTag = TagObject | string | number;

/** Name keys cannot collide with existing numeric tag ids. */
export type TagKey = number | `tag-name:${string}`;

/** The engine-facing representation of a tag. */
export interface TagItem {
  id: TagKey;
  name: string;
  isNew?: boolean;
}

/** Applies serializeTags' id rules while keeping names in a separate key space. */
export function tagKey(tag: HeldTag): TagKey {
  if (typeof tag === "number") {
    return tag;
  }
  if (typeof tag === "string") {
    return `tag-name:${tag.toLowerCase()}`;
  }
  const id = Number(tag.id);
  if (!tag.isNew && Number.isInteger(id) && id > 0) {
    return id;
  }
  return `tag-name:${tag.name.toLowerCase()}`;
}

/** Creates an engine row whose key remains distinct from numeric tag ids. */
export function createTagItem(name: string): TagItem & { isNew: true } {
  return { id: `tag-name:${name.toLowerCase()}`, name, isNew: true };
}

/** Converts created rows to the consumer shape, preserving server rows by identity. */
export function tagFromItem<T extends TagObject>(item: T): T | TagObject {
  return item.isNew ? { id: item.name, name: item.name, isNew: true } : item;
}

/** Builds an engine row from a held value without treating string names as ids. */
export function tagItem(tag: HeldTag): TagItem {
  if (typeof tag === "string") {
    return { id: tagKey(tag), name: tag };
  }
  if (typeof tag === "number") {
    return { id: tag, name: String(tag) };
  }
  return {
    id: tagKey(tag),
    name: tag.name,
    ...(tag.isNew !== undefined ? { isNew: tag.isNew } : {}),
  };
}

/** Emits selected values in order, preferring held objects so consumer metadata survives. */
export function emitTags(
  ids: readonly TagKey[],
  { held, items }: { held: readonly HeldTag[]; items: readonly TagObject[] }
): TagObject[] {
  const heldByKey = new Map(held.map((tag) => [tagKey(tag), tag]));
  const itemsById = new Map(items.map((item) => [item.id, item]));
  return ids.map((id) => {
    const tag = heldByKey.get(id);
    if (typeof tag === "string") {
      return { name: tag };
    }
    if (typeof tag === "number") {
      return { id: tag, name: String(tag) };
    }
    if (tag) {
      return tag;
    }
    const item = itemsById.get(id);
    if (!item) {
      throw new Error(`No tag found for selected key ${id}`);
    }
    return tagFromItem(item);
  });
}
