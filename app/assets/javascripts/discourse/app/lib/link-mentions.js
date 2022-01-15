import deprecated from "discourse-common/lib/deprecated";
import { ajax } from "discourse/lib/ajax";
import { formatUsername } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";
import { userPath } from "discourse/lib/url";

let maxGroupMention;

function replaceSpan(element, username, opts) {
  let extra = {};
  let extraClass = [];
  const a = document.createElement("a");

  if (opts && opts.group) {
    if (opts.mentionable) {
      extra = {
        name: username,
        mentionableUserCount: opts.mentionable.user_count,
        maxMentions: maxGroupMention,
      };
      extraClass.push("notify");
    }

    a.setAttribute("href", getURL("/g/") + username);
    a.classList.add("mention-group", ...extraClass);
    a.innerText = `@${username}`;
  } else {
    if (opts && opts.cannot_see) {
      extra = { name: username };
      extraClass.push("cannot-see");
    }

    a.href = userPath(username.toLowerCase());
    a.classList.add("mention", ...extraClass);
    a.innerText = `@${formatUsername(username)}`;
  }

  Object.keys(extra).forEach((key) => {
    a.dataset[key] = extra[key];
  });

  element.replaceWith(a);
}

const found = {};
const foundGroups = {};
const mentionableGroups = {};
const checked = {};
export const cannotSee = {};

function updateFound(mentions, usernames) {
  mentions.forEach((mention, index) => {
    const username = usernames[index];
    if (found[username.toLowerCase()]) {
      replaceSpan(mention, username, { cannot_see: cannotSee[username] });
    } else if (mentionableGroups[username]) {
      replaceSpan(mention, username, {
        group: true,
        mentionable: mentionableGroups[username],
      });
    } else if (foundGroups[username]) {
      replaceSpan(mention, username, { group: true });
    } else if (checked[username]) {
      mention.classList.add("mention-tested");
    }
  });
}

export function linkSeenMentions(elem, siteSettings) {
  // eslint-disable-next-line no-undef
  if (elem instanceof jQuery) {
    elem = elem[0];

    deprecated("linkSeenMentions now expects a DOM node as first parameter", {
      since: "2.8.0.beta7",
      dropFrom: "2.9.0.beta1",
    });
  }

  const mentions = [
    ...elem.querySelectorAll("span.mention:not(.mention-tested)"),
  ];
  if (mentions.length) {
    const usernames = mentions.map((m) => m.innerText.substr(1));
    updateFound(mentions, usernames);
    return usernames
      .uniq()
      .filter(
        (u) => !checked[u] && u.length >= siteSettings.min_username_length
      );
  }
  return [];
}

// 'Create a New Topic' scenario is not supported (per conversation with codinghorror)
// https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
export function fetchUnseenMentions(usernames, topic_id) {
  return ajax(userPath("is_local_username"), {
    data: { usernames, topic_id },
  }).then((r) => {
    r.valid.forEach((v) => (found[v] = true));
    r.valid_groups.forEach((vg) => (foundGroups[vg] = true));
    r.mentionable_groups.forEach((mg) => (mentionableGroups[mg.name] = mg));
    Object.entries(r.cannot_see).forEach(
      ([username, reason]) => (cannotSee[username] = reason)
    );
    maxGroupMention = r.max_users_notified_per_group_mention;
    usernames.forEach((u) => (checked[u] = true));
    return r;
  });
}
