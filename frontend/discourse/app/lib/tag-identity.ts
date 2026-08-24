import getURL from "discourse/lib/get-url";

/**
 * The subset of a tag needed to identify it. Matches the shape serialized by
 * the server, and is also satisfied by `Tag` models. `original_name` is only
 * sent when `name` holds a localization.
 */
export interface TagLike {
  name: string;
  id?: number;
  slug?: string;
  original_name?: string;
}

/**
 * A tag can be referred to by its slug or by its name, and the two differ once
 * the name isn't already slug-shaped. Never by its localized name: that would
 * only match for readers of one language.
 *
 * @returns Every string that refers to `tag`, most stable first.
 */
export function tagIdentifiers(tag: TagLike): string[] {
  const name = originalTagName(tag);

  return tag.slug && tag.slug !== name ? [tag.slug, name] : [name];
}

/**
 * The untranslated name. Tag routes are filtered on it server-side, so a
 * localized `name` cannot be used to build them.
 */
export function originalTagName(tag: string | TagLike): string {
  return typeof tag === "string" ? tag : tag.original_name || tag.name;
}

/** The name as it appears in the routes that look tags up by name. */
export function tagRouteName(tag: string | TagLike): string {
  // A dot would be read as a format separator.
  return originalTagName(tag).toLowerCase().replaceAll(".", "%2E");
}

/**
 * The canonical path to a tag's topic list. Tags without an id — legacy
 * payloads which serialize to a bare name — fall back to the name-only route.
 */
export function tagPath(tag: string | TagLike): string {
  if (typeof tag !== "string" && tag.id) {
    return `/tag/${slugForUrl(tag.slug, tag.id)}/${tag.id}`;
  }

  return `/tag/${tagRouteName(tag)}`;
}

/** The dynamic segments of the `tag.show` route, matching {@link tagPath}. */
export function tagRouteModels(
  tag: TagLike & { id: number }
): [string, number] {
  return [slugForUrl(tag.slug, tag.id), tag.id];
}

/** The placeholder the server falls back to for tags without a slug. */
function slugForUrl(slug: string | undefined, id: number): string {
  return slug || `${id}-tag`;
}

/** {@link tagPath}, prefixed with the site's base path. */
export function tagUrl(tag: string | TagLike): string {
  return getURL(tagPath(tag));
}
