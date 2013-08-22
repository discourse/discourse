/**
  Supports Discourse's custom @mention syntax for calling out a user in a post.
  It will add a special class to them, and create a link if the user is found in a
  local map.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;

  /**
    Parses out @username mentions.

    @method parseMentions
    @param {String} text the text match
    @param {Array} match the match found
    @param {Array} prev the previous jsonML
    @return {Array} an array containing how many chars we've replaced and the jsonML content for it.
    @namespace Discourse.Dialect
  **/
  dialect.inline['@'] = function parseMentions(text, match, prev) {

    // We only care about mentions on word boundaries
    if (prev && (prev.length > 0)) {
      var last = prev[prev.length - 1];
      if (typeof last === "string" && (!last.match(/\W$/))) { return; }
    }

    var pattern = /^(@[A-Za-z0-9][A-Za-z0-9_]{2,14})(?=(\W|$))/m,
        m = pattern.exec(text);

    if (m) {
      var username = m[1],
          mentionLookup = dialect.options.mentionLookup || Discourse.Mention.lookupCache;

      if (mentionLookup(username.substr(1))) {
        return [username.length, ['a', {'class': 'mention', href: Discourse.getURL("/users/") + username.substr(1).toLowerCase()}, username]];
      } else {
        return [username.length, ['span', {'class': 'mention'}, username]];
      }
    }

  };

});
