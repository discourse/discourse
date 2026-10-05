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
    siteSettings.ai_ask_ai_combined_search_prototype &&
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
 * the same key.
 */
export function scopeFilter(key) {
  if (!key) {
    return null;
  }

  const [type, value] = key.split(/:(.*)/s);
  return FILTERS[type]?.(value) ?? null;
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
  const context = search.searchContext;

  if (context?.type === "topic") {
    return {
      key: `topic:${context.id}`,
      label: i18n("discourse_ai.ai_search.scope.this_topic"),
      tabLabel: i18n("discourse_ai.ai_search.tabs.this_topic"),
    };
  }

  if (inPMInboxContext) {
    return {
      key: "messages",
      label: i18n("discourse_ai.ai_search.scope.messages"),
      tabLabel: i18n("discourse_ai.ai_search.tabs.messages"),
    };
  }

  switch (context?.type) {
    case "category": {
      const name = context.category?.name ?? context.id;
      return { key: `category:${context.id}`, label: name, tabLabel: name };
    }
    case "tag":
    case "tagIntersection": {
      const name = context.tagId ?? context.name ?? context.id;
      return name
        ? { key: `tag:${name}`, label: `#${name}`, tabLabel: `#${name}` }
        : null;
    }
    case "user": {
      const name = `@${context.user?.username ?? context.id}`;
      return { key: `user:${context.id}`, label: name, tabLabel: name };
    }
  }

  return null;
}
