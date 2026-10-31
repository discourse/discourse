import { trackedMap } from "@ember/reactive/collections";
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

/** The server's limit on names in one lookup. */
const MAX_LOOKUP_NAMES = 100;

/**
 * Ids by lowercased stored name, from every lookup and search this session. Tracked, so a value
 * keyed by a held name re-keys by id once the id is known.
 */
const tagIdsByName = trackedMap<string, number>();

/** Lowercased names a lookup found no tag for, so they are not asked for again. */
const missingNames = new Set<string>();

/** Lookups in flight, by lowercased name. */
const pendingNames = new Map<string, Promise<void>>();

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
  rememberTagIds(result.results);
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

/**
 * Finds the named tags the context allows, in one request for at most the server's 100
 * names. `forbiddenNames` lists names that exist but aren't allowed there; any other missing
 * name has no tag.
 */
export async function findTagsByNames(
  names: readonly string[],
  { context }: { context: TagSearchContext }
): Promise<{ items: TagRow[]; forbiddenNames: string[] }> {
  const result: { results: TagRow[]; forbidden_names?: string[] } = await ajax(
    "/tags/filter/search",
    {
      data: {
        names: names.slice(0, MAX_LOOKUP_NAMES),
        categoryId: context.categoryId,
        selected_tag_ids: context.selectedTagIds?.slice(0, 100),
        ...(!context.everyTag ? { filterForInput: true } : {}),
        ...(context.excludeSynonyms !== undefined
          ? { excludeSynonyms: context.excludeSynonyms }
          : {}),
        ...(context.excludeHasSynonyms !== undefined
          ? { excludeHasSynonyms: context.excludeHasSynonyms }
          : {}),
      },
    }
  );
  rememberTagIds(result.results);
  return {
    items: result.results,
    forbiddenNames: result.forbidden_names ?? [],
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

/** The id of a tag known by its stored name, from any lookup or search this session. */
export function knownTagId(name: string): number | undefined {
  return tagIdsByName.get(name.toLowerCase());
}

/**
 * Looks up the ids of stored names not yet known, in one request per 100 names. Any visible tag
 * resolves, whatever field asks; read the ids with {@link knownTagId}.
 */
export async function resolveTagNames(names: readonly string[]): Promise<void> {
  const unknown = [...new Set(names.map((name) => name.toLowerCase()))].filter(
    (name) =>
      !tagIdsByName.has(name) &&
      !missingNames.has(name) &&
      !pendingNames.has(name)
  );
  const requests = [];
  for (let offset = 0; offset < unknown.length; offset += MAX_LOOKUP_NAMES) {
    const chunk = unknown.slice(offset, offset + MAX_LOOKUP_NAMES);
    const request = lookUpNames(chunk).finally(() => {
      for (const name of chunk) {
        if (pendingNames.get(name) === request) {
          pendingNames.delete(name);
        }
      }
    });
    chunk.forEach((name) => pendingNames.set(name, request));
    requests.push(request);
  }
  const inFlight = names
    .map((name) => pendingNames.get(name.toLowerCase()))
    .filter((request) => request !== undefined);
  await Promise.all(new Set([...requests, ...inFlight]));
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

/** Forgets every known id and cached miss. */
export function resetTagSourceCache(): void {
  tagIdsByName.clear();
  missingNames.clear();
  pendingNames.clear();
}

/** Records the id of every row by its stored name. */
function rememberTagIds(rows: readonly TagRow[]): void {
  for (const row of rows) {
    const name = storedName(row).toLowerCase();
    if (tagIdsByName.get(name) !== row.id) {
      tagIdsByName.set(name, row.id);
    }
  }
}

/** Looks a chunk of names up and records which have a tag. */
async function lookUpNames(names: string[]): Promise<void> {
  const result: { results: TagRow[] } = await ajax("/tags/filter/search", {
    data: { names },
  });
  rememberTagIds(result.results);
  for (const name of names) {
    if (!tagIdsByName.has(name)) {
      missingNames.add(name);
    }
  }
}
