import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";

let checked = {};
let foundUsers = {};
let userReasons = {};
let foundGroups = {};
let groupReasons = {};
let maxGroupMention;

export function resetMentions() {
  checked = {};
  foundUsers = {};
  userReasons = {};
  foundGroups = {};
  groupReasons = {};
  maxGroupMention = null;
}

function replaceSpan(element, name, opts) {
  const a = document.createElement("a");

  if (opts.group) {
    a.href = getURL(`/g/${name}`);
    a.innerText = `@${name}`;
    a.classList.add("mention-group");

    if (!opts.reason && opts.details) {
      a.dataset.mentionableUserCount = opts.details.user_count;
      a.dataset.maxMentions = maxGroupMention;
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

function updateFound(mentions, names) {
  mentions.forEach((mention, index) => {
    const name = names[index];
    if (foundUsers[name.toLowerCase()]) {
      replaceSpan(mention, name, {
        reason: userReasons[name],
      });
    } else if (foundGroups[name]) {
      replaceSpan(mention, name, {
        group: true,
        details: foundGroups[name],
        reason: groupReasons[name],
      });
    } else if (checked[name]) {
      mention.classList.add("mention-tested");
    }
  });
}

export function linkSeenMentions(element, siteSettings) {
  const mentions = [
    ...element.querySelectorAll("span.mention:not(.mention-tested)"),
  ];

  if (mentions.length === 0) {
    return [];
  }

  const names = mentions.map((mention) => mention.innerText.slice(1));
  updateFound(mentions, names);

  return names
    .uniq()
    .filter(
      (name) =>
        !checked[name] && name.length >= siteSettings.min_username_length
    );
}

export async function fetchUnseenMentions({ names, topicId, allowedNames }) {
  const response = await ajax("/composer/mentions", {
    data: { names, topic_id: topicId, allowed_names: allowedNames },
  });

  names.forEach((name) => (checked[name] = true));
  response.users.forEach((username) => (foundUsers[username] = true));
  Object.entries(response.user_reasons).forEach(
    ([username, reason]) => (userReasons[username] = reason)
  );
  Object.entries(response.groups).forEach(
    ([name, details]) => (foundGroups[name] = details)
  );
  Object.entries(response.group_reasons).forEach(
    ([name, reason]) => (groupReasons[name] = reason)
  );
  maxGroupMention = response.max_users_notified_per_group_mention;

  return response;
}
