/** A tag held by a consumer, including name-only and newly created tags. */
export interface TagObject {
  id?: number | string | null;
  name: string;
  original_name?: string;
  isNew?: boolean;
}

/** Primitive held values distinguish numeric ids from names, even numeric-looking names. */
export type HeldTag = TagObject | string | number;

/** Name keys cannot collide with existing numeric tag ids. */
export type TagKey = number | `tag-name:${string}`;

/** The engine-facing representation of a tag. */
export interface TagRecord {
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
export function createTagRecord(name: string): TagRecord & { isNew: true } {
  return { id: `tag-name:${name.toLowerCase()}`, name, isNew: true };
}

/** Converts created rows to the consumer shape, preserving server rows by identity. */
export function tagFromRecord<T extends TagObject>(record: T): T | TagObject {
  return record.isNew
    ? { id: record.name, name: record.name, isNew: true }
    : record;
}

/** Builds an engine row from a held value without treating string names as ids. */
export function tagRecord(tag: HeldTag): TagRecord {
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
  { held, records }: { held: readonly HeldTag[]; records: readonly TagObject[] }
): TagObject[] {
  const heldByKey = new Map(held.map((tag) => [tagKey(tag), tag]));
  const recordsById = new Map(records.map((record) => [record.id, record]));
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
    const record = recordsById.get(id);
    if (!record) {
      throw new Error(`No tag found for selected key ${id}`);
    }
    return tagFromRecord(record);
  });
}
