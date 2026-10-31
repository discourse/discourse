import { ajax } from "discourse/lib/ajax";

/** A server tag row with the optional reason that prevents selection. */
export interface TagRow {
  id: number;
  name: string;
  /** The stored name, present only when `name` is a translation. */
  original_name?: string;
  text?: string;
  count?: number;
  disabled?: boolean;
  title?: string;
  description?: string;
}

/** Search dependencies; selectedTagIds contains only ids already resolved by the caller. */
export interface TagSearchContext {
  categoryId?: number;
  selectedTagIds?: readonly number[];
  everyTag?: boolean;
  excludeSynonyms?: boolean;
  excludeHasSynonyms?: boolean;
  prioritizeRecentTags?: boolean;
}

/** Search rows and validation metadata for the queried term. */
export interface TagSearchResult {
  items: TagRow[];
  forbidden?: boolean | string;
  forbiddenMessage?: string;
  /** The first unmet required group; `remaining_count` is how many more of its tags are needed. */
  requiredTagGroup?: {
    name: string;
    min_count: number;
    remaining_count: number;
  } | null;
}

const tagIdsByNames = new Map<string, Promise<Set<number>>>();

/** Returns the stored tag name when the displayed name is translated. */
export function storedName(row: {
  name: string;
  original_name?: string;
}): string {
  return row.original_name ?? row.name;
}

/** Searches using resolved held ids, leaving request failures for the caller to display. */
export async function searchTags(
  filter: string,
  {
    context,
    limit,
    siteSettings,
  }: {
    context: TagSearchContext;
    limit?: number;
    siteSettings: {
      max_tag_search_results: number;
      tags_sort_alphabetically?: boolean;
      max_tag_length: number;
      force_lowercase_tags: boolean;
    };
  }
): Promise<TagSearchResult> {
  const result: {
    results: TagRow[];
    forbidden?: TagSearchResult["forbidden"];
    forbidden_message?: string;
    required_tag_group?: TagSearchResult["requiredTagGroup"];
  } = await ajax("/tags/filter/search", {
    data: {
      q: filter,
      limit: Math.min(
        limit ?? siteSettings.max_tag_search_results,
        siteSettings.max_tag_search_results
      ),
      categoryId: context.categoryId,
      selected_tag_ids: context.selectedTagIds?.slice(0, 100),
      ...(!context.everyTag ? { filterForInput: true } : {}),
      ...(context.excludeSynonyms !== undefined
        ? { excludeSynonyms: context.excludeSynonyms }
        : {}),
      ...(context.excludeHasSynonyms !== undefined
        ? { excludeHasSynonyms: context.excludeHasSynonyms }
        : {}),
      ...(context.prioritizeRecentTags !== undefined
        ? { prioritizeRecentTags: context.prioritizeRecentTags }
        : {}),
    },
  });
  const items = result.results.map((row) =>
    row.disabled ? { ...row, description: row.title } : row
  );
  return {
    items: sortTagRows(items, {
      alphabetical:
        !!siteSettings.tags_sort_alphabetically &&
        !context.prioritizeRecentTags,
      exact: cleanTagName(filter, siteSettings),
    }),
    forbidden: result.forbidden,
    forbiddenMessage: result.forbidden_message,
    requiredTagGroup: result.required_tag_group,
  };
}

/** Searches groups in server order, using their names as selection keys. */
export async function searchTagGroups(
  filter: string,
  {
    siteSettings,
  }: {
    siteSettings: { max_tag_search_results: number };
  }
): Promise<Array<{ id: string; name: string }>> {
  const result: { results: Array<{ name: string }> } = await ajax(
    "/tag_groups/filter/search",
    {
      data: { q: filter, limit: siteSettings.max_tag_search_results },
    }
  );
  return result.results.map(({ name }) => ({ id: name, name }));
}

/** Resolves a name set to ids; localized response names must never be matched to input names. */
export async function findTagIdsByNames(
  names: readonly string[]
): Promise<Set<number>> {
  const normalized = [
    ...new Set(names.map((name) => name.toLowerCase())),
  ].sort();
  if (!normalized.length) {
    return new Set();
  }
  const key = JSON.stringify(normalized);
  let pending = tagIdsByNames.get(key);
  if (!pending) {
    pending = resolveTagIds(normalized);
    tagIdsByNames.set(key, pending);
  }
  try {
    return new Set(await pending);
  } catch (error) {
    if (tagIdsByNames.get(key) === pending) {
      tagIdsByNames.delete(key);
    }
    throw error;
  }
}

/** Returns category top tags when available, otherwise the site's top tags. */
export function topTags<T>({
  site,
  categoryId,
}: {
  site: { category_top_tags?: T[] | null; top_tags?: T[] | null };
  categoryId?: number;
}): T[] {
  return (
    (categoryId ? site.category_top_tags : undefined) ?? site.top_tags ?? []
  );
}

/**
 * Cleans a typed name the way the server's `clean_tag` does, step for step, so a created tag is
 * stored as shown. `tests/fixtures/tag-clean-parity.json` pins both sides.
 */
export function cleanTagName(
  input: string,
  siteSettings: {
    max_tag_length: number;
    force_lowercase_tags: boolean;
  }
): string {
  if (siteSettings.force_lowercase_tags) {
    input = input.toLowerCase();
  }
  const cleaned = input
    // Ruby's strip removes only ASCII whitespace and NUL; other spaces become dashes below.
    .replace(/^[\0\t\n\v\f\r ]+|[\0\t\n\v\f\r ]+$/g, "")
    .replace(/\p{White_Space}+/gu, "-")
    // Ruby's [[:word:][:punct:]], whose punctuation includes these ASCII symbols.
    .replace(/[^\p{L}\p{M}\p{Nd}\p{Pc}\p{P}$+<=>^`|~]+/gu, "")
    .replace(/[\/\?#\[\]@!\$&'\(\)\*\+,;=%\\`^\s|\{\}"<>]+/g, "")
    .replace(/-{2,}/g, "-");
  return Array.from(cleaned)
    .slice(0, siteSettings.max_tag_length)
    .join("")
    .replace(/^\.+|\.+$/g, "");
}

/**
 * Sorts enabled and disabled groups separately, or preserves the original array and order. A row
 * whose stored name equals `exact` leads its group, as the server ranks it.
 */
export function sortTagRows<
  T extends { name: string; original_name?: string; disabled?: boolean },
>(
  rows: T[],
  { alphabetical, exact }: { alphabetical: boolean; exact?: string }
): T[] {
  if (!alphabetical) {
    return rows;
  }
  const term = exact?.toLowerCase();
  const isExact = (row: T) => !!term && storedName(row).toLowerCase() === term;
  const byName = (a: T, b: T) =>
    Number(isExact(b)) - Number(isExact(a)) || a.name.localeCompare(b.name);
  return [
    ...rows.filter((row) => !row.disabled).sort(byName),
    ...rows.filter((row) => row.disabled).sort(byName),
  ];
}

/** Clears both successful name resolutions and cached misses. */
export function resetTagSourceCache(): void {
  tagIdsByNames.clear();
}

/** Splits name lookups at the list endpoint's page size to avoid silently losing ids. */
async function resolveTagIds(names: string[]): Promise<Set<number>> {
  const ids = new Set<number>();
  for (let offset = 0; offset < names.length; offset += 51) {
    const result: { list_tags: Array<{ id: number | string }> } = await ajax(
      "/tags/list.json",
      {
        data: { only_tags: names.slice(offset, offset + 51).join(",") },
      }
    );
    for (const tag of result.list_tags) {
      const id = Number(tag.id);
      if (Number.isInteger(id) && id > 0) {
        ids.add(id);
      }
    }
  }
  return ids;
}
