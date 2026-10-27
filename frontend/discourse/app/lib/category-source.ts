import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import type { CategoryRecord } from "discourse/ui-kit/select/recipes/categories/category-types";

/** TODO(typescript-pending): Remove when Site declares its serialized flag and record collection types. */
interface CategorySite extends Site {
  lazy_load_categories?: boolean;
  categoriesById: Map<number, CategoryRecord>;
  categoriesByParentId: Map<number, CategoryRecord[]>;
  updateCategories(pojos: object[]): CategoryRecord[];
}

/** TODO(typescript-pending): Remove this boundary when Site declares the singleton's static methods. */
function currentSite(): CategorySite {
  return (Site as typeof Site & { current(): CategorySite }).current();
}

/** Server-supported search rules; omitted options retain the server defaults. */
export interface CategorySearchOptions {
  /** Matches category names within the allowed scope. */
  term: string;
  /** One-based page number. */
  page?: number;
  /** Opaque continuation from the preceding page; null starts the first page. */
  cursor?: unknown;
  /** Direct children of this id, or top-level categories when set to -1. */
  parentCategoryId?: number;
  /** Category ids to omit from results. */
  rejectIds?: readonly number[];
  /** Whether the uncategorized category may appear. */
  includeUncategorized?: boolean;
  /** Whether categories with parents may appear in the results. */
  includeSubcategories?: boolean;
  /** Category whose branch the server should prioritize. */
  prioritizedId?: number;
  /** Restricts results to categories where topics can be created. */
  onlyPostable?: boolean;
  /** Cancels the fetch and prevents its response from updating the site. */
  signal?: AbortSignal;
}

/** One server page, with records shared by site lookups and category badges. */
export interface CategoryPage {
  /** Matches in server order. */
  categories: CategoryRecord[];
  /** Ancestors needed to render category badges. */
  ancestors: CategoryRecord[];
  /** Total server matches before pagination. */
  total: number;
  /** Whether another server page remains. */
  hasMore: boolean;
  /** Opaque continuation, consumed only by this source. */
  cursor?: unknown;
}

/** Validates source-owned continuation without exposing its representation to recipes. */
function continuation(
  value: unknown
): { page: number; received: number } | undefined {
  if (
    typeof value === "object" &&
    value !== null &&
    "page" in value &&
    typeof value.page === "number" &&
    "received" in value &&
    typeof value.received === "number"
  ) {
    return { page: value.page, received: value.received };
  }
}

/** Fetches one page and its ancestors; cancellation rejects without merging late rows. */
export async function fetchCategoryPage(
  options: CategorySearchOptions
): Promise<CategoryPage> {
  const { signal } = options;
  signal?.throwIfAborted();
  const site = currentSite();
  const previous = continuation(options.cursor);
  const page =
    previous?.page ?? options.page ?? (options.cursor === null ? 1 : undefined);
  const data = Object.fromEntries(
    Object.entries({
      term: options.term,
      page,
      parent_category_id: options.parentCategoryId,
      reject_category_ids: options.rejectIds,
      include_uncategorized: options.includeUncategorized,
      include_subcategories: options.includeSubcategories,
      prioritized_category_id: options.prioritizedId,
      only_postable: options.onlyPostable,
      include_ancestors: true,
    }).filter(([, value]) => value !== undefined)
  );

  let onAbort: (() => void) | undefined;
  try {
    // The transport does not observe signals, so cancellation must settle independently.
    const result = await new Promise<{
      categories: Array<{ id: number } & Record<string, unknown>>;
      ancestors?: Array<{ id: number } & Record<string, unknown>>;
      categories_count: number;
    }>((resolve, reject) => {
      onAbort = () => reject(signal?.reason);
      signal?.addEventListener("abort", onAbort, { once: true });
      ajax("/categories/search", { type: "POST", data, signal }).then(
        resolve,
        reject
      );
    });
    signal?.throwIfAborted();

    const ancestors = result.ancestors ?? [];
    const records = site.updateCategories([...ancestors, ...result.categories]);
    const received = (previous?.received ?? 0) + result.categories.length;
    const hasMore =
      result.categories.length > 0 && received < result.categories_count;
    return {
      categories: records.slice(ancestors.length),
      ancestors: records.slice(0, ancestors.length),
      total: result.categories_count,
      hasMore,
      cursor: hasMore ? { page: (page ?? 1) + 1, received } : undefined,
    };
  } finally {
    if (onAbort) {
      signal?.removeEventListener("abort", onAbort);
    }
  }
}

/** Resolves already-loaded ids synchronously, in input order, without requesting missing records. */
export function knownCategories(
  ids: readonly (number | string)[]
): CategoryRecord[] {
  const byId = currentSite().categoriesById;
  return ids.flatMap((value) => {
    const id = Number(value);
    const category =
      Number.isSafeInteger(id) && id > 0 ? byId.get(id) : undefined;
    return category ? [category] : [];
  });
}

/** Resolves held ids in input order, preserving duplicates and dropping missing records. */
export async function resolveCategories(
  ids: readonly (number | string)[]
): Promise<CategoryRecord[]> {
  const site = currentSite();
  const normalized = ids
    .map(Number)
    .filter((id) => Number.isSafeInteger(id) && id > 0);
  const known = site.categoriesById;
  if (site.lazy_load_categories) {
    const missing = [...new Set(normalized.filter((id) => !known.has(id)))];
    if (missing.length) {
      await Category.asyncFindByIds(missing);
    }
  }

  return knownCategories(normalized);
}

/** Returns the root and every descendant in breadth-first order, paging lazy children. */
export async function loadDescendants(
  category: CategoryRecord,
  {
    signal,
  }: { /** Cancels pending descendant pages. */ signal?: AbortSignal } = {}
): Promise<CategoryRecord[]> {
  signal?.throwIfAborted();
  const site = currentSite();
  const descendants = [category];
  const seen = new Set<number>([category.id]);
  const lazy = !!site.lazy_load_categories;
  const byParent = lazy ? undefined : site.categoriesByParentId;

  for (let index = 0; index < descendants.length; index++) {
    const parent = descendants[index];
    if (!lazy) {
      for (const child of byParent?.get(parent.id) ?? []) {
        if (!seen.has(child.id)) {
          seen.add(child.id);
          descendants.push(child);
        }
      }
      continue;
    }

    if (parent.has_children === false) {
      continue;
    }

    let cursor: unknown = null;
    while (true) {
      const result = await fetchCategoryPage({
        term: "",
        parentCategoryId: parent.id,
        cursor,
        signal,
      });
      for (const child of result.categories) {
        if (!seen.has(child.id)) {
          seen.add(child.id);
          descendants.push(child);
        }
      }
      if (!result.hasMore) {
        break;
      }
      cursor = result.cursor;
    }
  }
  return descendants;
}
