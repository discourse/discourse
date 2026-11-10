import renderTag, {
  type RenderableTag,
  type RenderTagOptions,
} from "discourse/lib/render-tag";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

/** The topic properties `renderTags` reads. */
export interface TagsTopic {
  tags?: RenderableTag[] | null;

  /** The tag descriptions, by tag name. */
  tags_descriptions?: Record<string, string> | null;

  get(key: string): unknown;
}

/** Options for `renderTags`. Each tag is rendered with them too. */
export interface RenderTagsOptions extends RenderTagOptions {
  /** The tags to render without a topic. */
  tags?: RenderableTag[] | null;

  /** `"list"` renders the topic's visible list tags. */
  mode?: string;

  /** Classes to add to tags, by tag name. */
  tagClasses?: Record<string, string>;

  /** Classes to add to the list. */
  className?: string;
}

/** Returns more items for a topic's tag list. */
export type TagsHtmlCallback = (
  topic: TagsTopic,
  params: RenderTagsOptions | null | undefined
) => string | (string | null | undefined | false)[] | null | undefined | false;

let callbacks: TagsHtmlCallback[] | null = null;
let priorities: number[] | null = null;

/**
 * Registers a function that adds items to topics' tag lists.
 *
 * @param callback - Returns the HTML of the items.
 * @param options - The options.
 */
export function addTagsHtmlCallback(
  callback: TagsHtmlCallback,
  options?: {
    /** Callbacks with a higher priority come first. Defaults to 0. */
    priority?: number;
  } | null
) {
  callbacks = callbacks || [];
  priorities = priorities || [];
  const priority = (options && options.priority) || 0;

  let i = 0;
  while (i < priorities.length && priorities[i] > priority) {
    i += 1;
  }

  priorities.splice(i, 0, priority);
  callbacks.splice(i, 0, callback);
}

/** Removes the registered tag list callbacks. */
export function clearTagsHtmlCallbacks() {
  callbacks = null;
  priorities = null;
}

/**
 * Renders a topic's tags, and the items registered callbacks add, as a list.
 *
 * @param topic - The topic.
 * @param params - The options.
 * @returns The list HTML, or `""` when it would be empty.
 */
export default function (
  topic: TagsTopic | null | undefined,
  params?: RenderTagsOptions | null
): string {
  let tags = topic?.tags || params?.tags;
  let buffer = "";
  let tagsForUser: string | null | undefined = null;
  let tagName: string | undefined;

  const isPrivateMessage = topic?.get("isPrivateMessage") as
    | boolean
    | undefined;

  if (params) {
    if (params.mode === "list") {
      tags = topic?.get("visibleListTags") as RenderableTag[] | undefined;
    }
    if (params.tagsForUser) {
      tagsForUser = params.tagsForUser;
    }
    if (params.tagName) {
      tagName = params.tagName;
    }
  }

  const separator = (index: number) => {
    return applyValueTransformer("tag-separator", ",", {
      topic,
      index,
    });
  };

  const separatorSpan = (index: number) => {
    return `<span class="discourse-tags__tag-separator">${separator(
      index
    )}</span>`;
  };

  const callbackResults: string[] = [];

  if (callbacks && topic) {
    callbacks.forEach((c) => {
      const html = c(topic, params);
      if (Array.isArray(html)) {
        callbackResults.push(...(html.filter(Boolean) as string[]));
      } else if (html) {
        callbackResults.push(html);
      }
    });
  }

  const hasContent = (tags && tags.length > 0) || callbackResults.length > 0;

  if (hasContent) {
    const classNames = ["discourse-tags"];

    if (params?.className) {
      classNames.push(params.className);
    }

    buffer = `<ul class='${classNames.join(" ")}' aria-label=${i18n("tagging.tags")}>`;

    let currentIndex = 0;

    if (tags && tags.length > 0) {
      for (let i = 0; i < tags.length; i++) {
        const tag = tags[i];
        const tagStr = typeof tag === "string" ? tag : tag.name;
        const tagParams: RenderTagOptions = params ? { ...params } : {};

        if (params?.tagClasses && params?.tagClasses[tagStr]) {
          tagParams.extraClass = params.tagClasses[tagStr];
        }

        buffer += "<li>";
        buffer += renderTag(tag, {
          description: topic?.tags_descriptions?.[tagStr],
          isPrivateMessage,
          tagsForUser,
          tagName,
          ...tagParams,
        });

        // separator after each tag
        // except if it's the last tag
        // and there are no customizations
        if (i < tags.length - 1 || callbackResults.length > 0) {
          buffer += separatorSpan(currentIndex);
          currentIndex++;
        }
        buffer += "</li>";
      }
    }

    // add custom results with separator
    for (let i = 0; i < callbackResults.length; i++) {
      buffer += "<li>";
      buffer += callbackResults[i];

      // don't add separator to the last item
      if (i < callbackResults.length - 1) {
        buffer += separatorSpan(currentIndex);
        currentIndex++;
      }
      buffer += "</li>";
    }

    buffer += "</ul>";
  }

  return buffer;
}
