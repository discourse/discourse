import { ajax } from 'discourse/lib/ajax';
function replaceSpan($e, username, opts) {
  if (opts && opts.group) {
    var extra = "", extraClass = "";
    if (opts.mentionable) {
      extra = " data-name='" + username + "' data-mentionable-user-count='" + opts.mentionable.user_count + "' ";
      extraClass = " notify";
    }
    $e.replaceWith("<a href='" +
                  Discourse.getURL("/groups/") + username +
                  "' class='mention-group" + extraClass + "'" + extra + ">@" + username + "</a>");
  } else {
    $e.replaceWith("<a href='" +
                  Discourse.getURL("/users/") + username.toLowerCase() +
                  "' class='mention'>@" + username + "</a>");
  }
}

const found = [];
const foundGroups = [];
const mentionableGroups = [];
const checked = [];

function updateFound($mentions, usernames) {
  Ember.run.scheduleOnce('afterRender', function() {
    $mentions.each((i, e) => {
      const $e = $(e);
      const username = usernames[i];
      if (found.indexOf(username.toLowerCase()) !== -1) {
        replaceSpan($e, username);
      } else if (foundGroups.indexOf(username) !== -1) {
        const mentionable = _(mentionableGroups).where({name: username}).first();
        replaceSpan($e, username, {group: true, mentionable: mentionable});
      } else if (checked.indexOf(username) !== -1) {
        $e.addClass('mention-tested');
      }
    });
  });
}

export function linkSeenMentions($elem, siteSettings) {
  const $mentions = $('span.mention:not(.mention-tested)', $elem);
  if ($mentions.length) {
    const usernames = $mentions.map((_, e) => $(e).text().substr(1));
    const unseen = _.uniq(usernames).filter((u) => {
      return u.length >= siteSettings.min_username_length && checked.indexOf(u) === -1;
    });
    updateFound($mentions, usernames);
    return unseen;
  }

  return [];
}

export function fetchUnseenMentions($elem, usernames) {
  return ajax("/users/is_local_username", { data: { usernames } }).then(function(r) {
    found.push.apply(found, r.valid);
    foundGroups.push.apply(foundGroups, r.valid_groups);
    mentionableGroups.push.apply(mentionableGroups, r.mentionable_groups);
    checked.push.apply(checked, usernames);
    return r;
  });
}
