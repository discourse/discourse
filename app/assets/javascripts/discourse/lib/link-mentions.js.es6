import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";

let maxGroupMention;

function replaceSpan($e, username, opts) {
  let extra = "";
  let extraClass = "";

  if (opts && opts.group) {
    if (opts.mentionable) {
      extra = `data-name='${username}' data-mentionable-user-count='${opts.mentionable.user_count}' data-max-mentions='${maxGroupMention}'`;
      extraClass = "notify";
    }
    $e.replaceWith(
      `<a href='${Discourse.getURL("/g/") +
        username}' class='mention-group ${extraClass}' ${extra}>@${username}</a>`
    );
  } else {
    if (opts && opts.cannot_see) {
      extra = `data-name='${username}'`;
      extraClass = "cannot-see";
    }
    $e.replaceWith(
      `<a href='${userPath(
        username.toLowerCase()
      )}' class='mention ${extraClass}' ${extra}>@${formatUsername(
        username
      )}</a>`
    );
  }
}

const found = {};
const foundGroups = {};
const mentionableGroups = {};
const checked = {};
const cannotSee = [];

function updateFound($mentions, usernames) {
  Ember.run.scheduleOnce("afterRender", function() {
    $mentions.each((i, e) => {
      const $e = $(e);
      const username = usernames[i];
      if (found[username.toLowerCase()]) {
        replaceSpan($e, username, { cannot_see: cannotSee[username] });
      } else if (foundGroups[username]) {
        replaceSpan($e, username, {
          group: true,
          mentionable: mentionableGroups[username]
        });
      } else if (checked[username]) {
        $e.addClass("mention-tested");
      }
    });
  });
}

export function linkSeenMentions($elem, siteSettings) {
  const $mentions = $("span.mention:not(.mention-tested)", $elem);
  if ($mentions.length) {
    const usernames = $mentions.map((_, e) =>
      $(e)
        .text()
        .substr(1)
    );
    updateFound($mentions, usernames);
    return _.uniq(usernames).filter(
      u => !checked[u] && u.length >= siteSettings.min_username_length
    );
  }
  return [];
}

// 'Create a New Topic' scenario is not supported (per conversation with codinghorror)
// https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
export function fetchUnseenMentions(usernames, topic_id) {
  return ajax(userPath("is_local_username"), {
    data: { usernames, topic_id }
  }).then(r => {
    r.valid.forEach(v => (found[v] = true));
    r.valid_groups.forEach(vg => (foundGroups[vg] = true));
    r.mentionable_groups.forEach(mg => (mentionableGroups[mg.name] = mg));
    r.cannot_see.forEach(cs => (cannotSee[cs] = true));
    maxGroupMention = r.max_users_notified_per_group_mention;
    usernames.forEach(u => (checked[u] = true));
    return r;
  });
}
