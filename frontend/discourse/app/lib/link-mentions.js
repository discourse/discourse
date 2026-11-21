import { ajax } from "discourse/lib/ajax";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";

let cache = createCache();

function createCache(key = null) {
  return {
    key,
    checked: {},
    foundUsers: {},
    userReasons: {},
    foundGroups: {},
    groupReasons: {},
    maxGroupMention: null,
  };
}

export function resetMentions() {
  cache = createCache();
}

function contextKey({ topicId, allowedNames }) {
  const allowed = (allowedNames ?? [])
    .map((name) => name.toLowerCase())
    .sort()
    .join(",");
  return `${topicId ?? ""}|${allowed}`;
}

// Results depend on the topic and PM recipients, so they are never reused
// across contexts.
function cacheFor(context) {
  const key = contextKey(context);
  if (cache.key !== key) {
    cache = createCache(key);
  }
  return cache;
}

function replaceSpan(element, name, opts) {
  const a = document.createElement("a");

  if (opts.group) {
    a.href = getURL(`/g/${name}`);
    a.innerText = `@${name}`;
    a.classList.add("mention-group");

    if (!opts.reason && opts.details) {
      a.dataset.mentionableUserCount = opts.details.user_count;
      a.dataset.maxMentions = opts.maxGroupMention;
    }
  } else {
    a.href = userPath(name.toLowerCase());
    a.innerText = `@${formatUsername(name)}`;
    a.classList.add("mention");
  }

  a.dataset.name = name;
  if (opts.reason) {
    a.dataset.reason = opts.reason;

    if (opts.details) {
      a.dataset.notifiedUserCount = opts.details.notified_count;
    }
  }

  element.replaceWith(a);
}

function updateFound(mentions, names, found) {
  mentions.forEach((mention, index) => {
    const name = names[index];
    const lower = name.toLowerCase();
    if (found.foundUsers[lower]) {
      replaceSpan(mention, name, {
        reason: found.userReasons[lower],
      });
    } else if (found.foundGroups[lower]) {
      replaceSpan(mention, name, {
        group: true,
        details: found.foundGroups[lower],
        reason: found.groupReasons[lower],
        maxGroupMention: found.maxGroupMention,
      });
    } else if (found.checked[lower]) {
      mention.classList.add("mention-tested");
    }
  });
}

export function linkSeenMentions(element, siteSettings, context = {}) {
  const found = cacheFor(context);

  const mentions = [
    ...element.querySelectorAll("span.mention:not(.mention-tested)"),
  ];

  if (mentions.length === 0) {
    return [];
  }

  const names = mentions.map((mention) => mention.innerText.slice(1));
  updateFound(mentions, names, found);

  return uniqueItemsFromArray(names).filter(
    (name) =>
      !found.checked[name.toLowerCase()] &&
      name.length >= siteSettings.min_username_length
  );
}

export async function fetchUnseenMentions({ names, topicId, allowedNames }) {
  // Captured before the request so a late response cannot land in the cache
  // of a context the composer has since moved to.
  const found = cacheFor({ topicId, allowedNames });

  const response = await ajax("/composer/mentions", {
    data: { names, topic_id: topicId, allowed_names: allowedNames },
  });

  names.forEach((name) => (found.checked[name.toLowerCase()] = true));
  response.users.forEach(
    (username) => (found.foundUsers[username.toLowerCase()] = true)
  );
  Object.entries(response.user_reasons).forEach(
    ([username, reason]) => (found.userReasons[username.toLowerCase()] = reason)
  );
  Object.entries(response.groups).forEach(
    ([name, details]) => (found.foundGroups[name.toLowerCase()] = details)
  );
  Object.entries(response.group_reasons).forEach(
    ([name, reason]) => (found.groupReasons[name.toLowerCase()] = reason)
  );
  found.maxGroupMention = response.max_users_notified_per_group_mention;

  return response;
}
