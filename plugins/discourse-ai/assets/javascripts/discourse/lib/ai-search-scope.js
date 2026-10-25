import { i18n } from "discourse-i18n";

/**
 * @typedef {Object} AiSearchScope
 * @property {string} key what the server accepts, e.g. `category:12` or `messages`
 * @property {string} label how the scope is named within a sentence
 * @property {string} tabLabel how the scope's tab is named
 */

/**
 * Whether the header search answers and searches together for this user. It
 * fetches its own semantic matches, so features that add them to the menu
 * stand aside.
 */
export function combinedSearchActive(siteSettings, currentUser) {
  return Boolean(
    siteSettings.enable_ai_combined_search &&
    siteSettings.ai_ask_ai_enabled &&
    siteSettings.ai_ask_ai_agent &&
    currentUser?.can_use_ask_ai
  );
}

const FILTERS = {
  messages: () => "in:messages",
  topic: (value) => `topic:${value}`,
  category: (value) => `category:${value}`,
  tag: (value) => `tags:${value}`,
  user: (value) => `user:${value}`,
};

/**
 * The search filter a scope key stands for, mirroring the server's reading of
 * the same key. A key can join a category and tags with a space, as a tag page
 * within a category does.
 */
export function scopeFilter(key) {
  if (!key) {
    return null;
  }

  const filters = key.split(" ").map((part) => {
    const [type, value] = part.split(/:(.*)/s);
    return FILTERS[type]?.(value);
  });
  return filters.every(Boolean) ? filters.join(" ") : null;
}

/**
 * Whether semantic search can rank within a scope. Embeddings describe public
 * topics, so they cannot rank within one topic or among messages.
 */
export function semanticSearchable(key) {
  return !["topic", "messages"].includes(key?.split(":")[0]);
}

/**
 * The query as keyword search should see it, within the scope. Closing
 * punctuation is dropped: it adds nothing to the keywords, and a search within
 * a topic finds nothing when the term ends with it.
 */
export function withScope(query, key) {
  const keywords = (query ?? "").replace(/[\s?？!！.。]+$/u, "");
  return [keywords, scopeFilter(key)].filter(Boolean).join(" ");
}

/**
 * The scope the reader is searching from, or null when the search is site
 * wide.
 *
 * @param {Object} search the search service
 * @param {Object} options
 * @param {boolean} options.inPMInboxContext whether the menu is scoped to messages
 * @returns {AiSearchScope|null}
 */
export function contextScope(search, { inPMInboxContext }) {
  const place = contextPlace(search.searchContext);

  // a topic is always offered as a tab of its own
  if (place?.key.startsWith("topic:")) {
    return place;
  }

  if (inPMInboxContext) {
    return {
      key: "messages",
      label: i18n("discourse_ai.ai_search.scope.messages"),
      tabLabel: i18n("discourse_ai.ai_search.tabs.messages"),
    };
  }

  return place;
}

/**
 * The place a search context stands for, whether or not the menu searches
 * within it.
 *
 * @param {Object|null} context the search service's search context
 * @returns {AiSearchScope|null}
 */
export function contextPlace(context) {
  switch (context?.type) {
    case "topic":
      return {
        key: `topic:${context.id}`,
        label: i18n("discourse_ai.ai_search.scope.this_topic"),
        tabLabel: i18n("discourse_ai.ai_search.tabs.this_topic"),
      };
    case "category": {
      const name = context.category?.name ?? context.id;
      return { key: `category:${context.id}`, label: name, tabLabel: name };
    }
    case "tag":
    case "tagIntersection": {
      const tags = [
        context.tagId ?? context.name ?? context.id,
        ...(context.additionalTags ?? []),
      ].filter(Boolean);
      if (!tags.length) {
        return null;
      }

      const tagNames = tags.map((tag) => `#${tag}`).join(" ");
      const name = context.category
        ? `${context.category.name} ${tagNames}`
        : tagNames;
      const tagKey = `tag:${tags.join("+")}`;
      const key = context.categoryId
        ? `category:${context.categoryId} ${tagKey}`
        : tagKey;
      return { key, label: name, tabLabel: name };
    }
    case "user": {
      const name = `@${context.user?.username ?? context.id}`;
      return { key: `user:${context.id}`, label: name, tabLabel: name };
    }
  }

  return null;
}
