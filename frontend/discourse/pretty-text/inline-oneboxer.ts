import type { ajax as discourseAjax, AjaxError } from "discourse/lib/ajax";

/** An inline onebox the server looked up. */
export interface InlineOnebox {
  /** The url of the link. */
  url: string;
  /** The title that replaces the link text. Empty when nothing was found. */
  title?: string | null;
  /** An extra class for the link. */
  css_class?: string;
}

const TOO_MANY_REQUESTS = 429;

// A url maps to an empty object while its lookup is pending or found nothing.
const _cache: Record<string, Partial<InlineOnebox>> = {};

/**
 * Looks up the inline oneboxes of the given links and replaces each link's
 * text with its onebox title.
 *
 * The urls are looked up in batches, once each. A rate limited request stops
 * the lookup, and the urls it didn't finish are looked up again on a later
 * call.
 *
 * @param inline - The links to onebox, grouped by url.
 * @param ajax - The function that makes the request.
 * @param opts - The lookup options.
 */
export async function applyInlineOneboxes(
  inline: Record<string, HTMLElement[]>,
  ajax: typeof discourseAjax,
  opts?: {
    /** The id of the category the links are posted in. */
    categoryId?: number;
    /** The id of the topic the links are posted in. */
    topicId?: number;
    /** Called with the oneboxes that were found, after each batch. */
    onLoad?: (oneboxes: InlineOnebox[]) => void;
  } | null
) {
  opts = opts || {};

  const urls = Object.keys(inline).filter((url) => !_cache[url]);

  urls.forEach((url) => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  if (urls.length === 0) {
    return;
  }

  const batchSize = 10;
  for (let i = 0; i < urls.length; i += batchSize) {
    const batch = urls.slice(i, i + batchSize);

    try {
      const result = await ajax<{ "inline-oneboxes": InlineOnebox[] }>(
        "/inline-onebox",
        {
          data: {
            urls: batch,
            category_id: opts.categoryId,
            topic_id: opts.topicId,
          },
        }
      );
      const loaded = result["inline-oneboxes"].filter((onebox) => onebox.title);
      loaded.forEach((onebox) => {
        _cache[onebox.url] = onebox;

        const links = inline[onebox.url] || [];
        links.forEach((link) => {
          // Only the oneboxes with a title were kept.
          link.innerText = onebox.title!;
          link.classList.add("inline-onebox");
          if (onebox.css_class) {
            link.classList.add(onebox.css_class);
          }
          link.classList.remove("inline-onebox-loading");
        });
      });
      if (loaded.length) {
        opts.onLoad?.(loaded);
      }
    } catch (err) {
      // A rejected `ajax` call has a `jqXHR`; other errors may carry a status.
      const rateLimited =
        ((err as AjaxError).jqXHR ?? (err as { status?: number })).status ===
        TOO_MANY_REQUESTS;

      if (rateLimited) {
        urls.slice(i).forEach((url) => delete _cache[url]);
        return;
      }

      // eslint-disable-next-line no-console
      console.error("Inline onebox request failed", err, batch);
    }
  }
}

export function cachedInlineOnebox(
  url: string
): Partial<InlineOnebox> | undefined {
  return _cache[url];
}

export function applyCachedInlineOnebox(
  url: string,
  onebox: Partial<InlineOnebox>
): Partial<InlineOnebox> {
  return (_cache[url] = onebox);
}

export function deleteCachedInlineOnebox(url: string): boolean {
  return delete _cache[url];
}

export function resetInlineOneboxCache() {
  Object.keys(_cache).forEach((url) => delete _cache[url]);
}
