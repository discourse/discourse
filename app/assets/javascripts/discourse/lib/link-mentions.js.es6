function replaceSpan($e, username) {
  $e.replaceWith("<a href='" +
                  Discourse.getURL("/users/") + username.toLowerCase() +
                  "' class='mention'>@" + username + "</a>");
}

const found = [];
const checked = [];

function updateFound($mentions, usernames) {
  Ember.run.scheduleOnce('afterRender', function() {
    $mentions.each((i, e) => {
      const $e = $(e);
      const username = usernames[i];
      if (found.indexOf(username.toLowerCase()) !== -1) {
        replaceSpan($e, username);
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
  return Discourse.ajax("/users/is_local_username", { data: { usernames } }).then(function(r) {
    found.push.apply(found, r.valid);
    checked.push.apply(checked, usernames);
  });
}
