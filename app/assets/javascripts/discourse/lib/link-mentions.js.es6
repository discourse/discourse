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
      if (found.indexOf(username) !== -1) {
        replaceSpan($e, username);
      } else {
        $e.removeClass('mention-loading').addClass('mention-tested');
      }
    });
  });
}


let linking = false;
export default function linkMentions($elem) {
  if (linking) { return Ember.RSVP.Promise.resolve(); }
  linking = true;

  return new Ember.RSVP.Promise(function(resolve) {
    const $mentions = $('span.mention:not(.mention-tested):not(.mention-loading)', $elem);
    if ($mentions.length) {
      const usernames = $mentions.map((_, e) => $(e).text().substr(1).toLowerCase());

      if (usernames.length) {
        $mentions.addClass('mention-loading');
        const uncached = _.uniq(usernames).filter((u) => { return checked.indexOf(u) === -1; });

        if (uncached.length) {
          return Discourse.ajax("/users/is_local_username", {
            data: { usernames: uncached}
          }).then(function(r) {
            found.push.apply(found, r.valid);
            checked.push.apply(checked, uncached);
            updateFound($mentions, usernames);
            resolve();
          });
        } else {
          updateFound($mentions, usernames);
        }
      }
    }

    resolve();
  }).finally(() => { linking = false });
}
