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
    Support for github style code blocks

    @method mentionSupport
    @param {Markdown.Block} block the block to examine
    @param {Array} next the next blocks in the sequence
    @return {Array} the JsonML containing the markup or undefined if nothing changed.
    @namespace Discourse.Dialect
  **/
  dialect.block['mentions'] = function mentionSupport(block, next) {
    var pattern = /(\W|^)(@[A-Za-z0-9][A-Za-z0-9_]{2,14})(?=(\W|$))/gm,
        result,
        remaining = block,
        m,
        mentionLookup = dialect.options.mentionLookup || Discourse.Mention.lookupCache;

    if (block.match(/^ {3}/)) { return; }
    if (block.match(/^\>/)) { return; }

    var pushIt = function(p) { result.push(p) },
        backtickCount = 0,
        dirty = false;

    while (m = pattern.exec(remaining)) {
      result = result || ['p'];

      var username = m[2],
          usernameIndex = remaining.indexOf(username),
          before = remaining.slice(0, usernameIndex),
          prevBacktickCount = backtickCount;


      pattern.lastIndex = 0;
      backtickCount = prevBacktickCount + (before.split('`').length - 1);
      var dontMention = ((backtickCount % 2) === 1);

      if (dontMention) {
        before = before + username;
        remaining = remaining.slice(usernameIndex + username.length);

        var nextMention = remaining.indexOf("@");
        if (nextMention !== -1) {
          before = before + remaining.slice(0, nextMention);
          backtickCount = prevBacktickCount + (before.split('`').length - 1);
          remaining = remaining.slice(nextMention);
          this.processInline(before).forEach(pushIt);
          continue;
        }

      } else {
        remaining = remaining.slice(usernameIndex + username.length);
      }

      if (before) {
        this.processInline(before).forEach(pushIt);
      }

      if (!dontMention) {
        if (mentionLookup(username.substr(1))) {
          result.push(['a', {'class': 'mention', href: Discourse.getURL("/users/") + username.substr(1).toLowerCase()}, username]);
        } else {
          result.push(['span', {'class': 'mention'}, username]);
        }
        dirty = true;
      }

      if (remaining && remaining.match(/\n/)) {
        next.unshift(MD.mk_block(remaining));
        return [result];
      }
    }

    if (dirty && result) {
      if (remaining.length) {
        this.processInline(remaining).forEach(pushIt);
      }
      return [result];
    }
  };

});
