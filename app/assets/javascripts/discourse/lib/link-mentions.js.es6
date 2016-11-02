import { ajax } from 'discourse/lib/ajax';

function replaceSpan($e, username, opts) {
  if (opts && opts.group) {
    let extra = "";
    let extraClass = "";
    if (opts.mentionable) {
      extra = `data-name='${username}' data-mentionable-user-count='${opts.mentionable.user_count}'`;
      extraClass = "notify";
    }
    $e.replaceWith(`<a href='${Discourse.getURL("/groups/") + username}' class='mention-group ${extraClass}' ${extra}>@${username}</a>`);
  } else {
    $e.replaceWith(`<a href='${Discourse.getURL("/users/") + username.toLowerCase()}' class='mention'>@${username}</a>`);
  }
}

const found = {};
const foundGroups = {};
const mentionableGroups = {};
const checked = {};

function updateFound($mentions, usernames) {
  Ember.run.scheduleOnce('afterRender', function() {
    $mentions.each((i, e) => {
      const $e = $(e);
      const username = usernames[i];
      if (found[username.toLowerCase()]) {
        replaceSpan($e, username);
      } else if (foundGroups[username]) {
        replaceSpan($e, username, { group: true, mentionable: mentionableGroups[username] });
      } else if (checked[username]) {
        $e.addClass('mention-tested');
      }
    });
  });
}

export function linkSeenMentions($elem, siteSettings) {
  const $mentions = $('span.mention:not(.mention-tested)', $elem);
  if ($mentions.length) {
    const usernames = $mentions.map((_, e) => $(e).text().substr(1));
    updateFound($mentions, usernames);
    return _.uniq(usernames).filter(u => !checked[u] && u.length >= siteSettings.min_username_length);
  }
  return [];
}

export function fetchUnseenMentions(usernames) {
  return ajax("/users/is_local_username", { data: { usernames } }).then(r => {
    r.valid.forEach(v => found[v] = true);
    r.valid_groups.forEach(vg => foundGroups[vg] = true);
    r.mentionable_groups.forEach(mg => mentionableGroups[mg] = true);
    usernames.forEach(u => checked[u] = true);
    return r;
  });
}
