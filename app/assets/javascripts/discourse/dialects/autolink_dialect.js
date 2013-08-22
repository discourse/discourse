/**
  This addition handles auto linking of text. When included, it will parse out links and create
  a hrefs for them.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;

  /**
    Parses out links from HTML.

    @method autoLink
    @param {Markdown.Block} block the block to examine
    @param {Array} next the next blocks in the sequence
    @return {Array} the JsonML containing the markup or undefined if nothing changed.
    @namespace Discourse.Dialect
  **/
  dialect.block['autolink'] = function autoLink(block, next) {
    var pattern = /(^|\s)((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
        result,
        remaining = block,
        m;

    var pushIt = function(p) { result.push(p) };

    while (m = pattern.exec(remaining)) {
      result = result || ['p'];

      var url = m[2],
          urlIndex = remaining.indexOf(url),
          before = remaining.slice(0, urlIndex);

      if (before.match(/\[\d+\]/)) { return; }

      pattern.lastIndex = 0;
      remaining = remaining.slice(urlIndex + url.length);

      if (before) {
        this.processInline(before).forEach(pushIt);
      }

      var displayUrl = url;
      if (url.match(/^www/)) { url = "http://" + url; }
      result.push(['a', {href: url}, displayUrl]);

      if (remaining && remaining.match(/\n/)) {
        next.unshift(MD.mk_block(remaining));
        remaining = [];
      }
    }

    if (result) {
      if (remaining.length) {
        this.processInline(remaining).forEach(pushIt);
      }
      return [result];
    }
  };

});