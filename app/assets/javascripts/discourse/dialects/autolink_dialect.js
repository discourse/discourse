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
    @param {String} text the text match
    @param {Array} match the match found
    @param {Array} prev the previous jsonML
    @return {Array} an array containing how many chars we've replaced and the jsonML content for it.
    @namespace Discourse.Dialect
  **/
  dialect.inline['http'] = dialect.inline['www'] = function autoLink(text, match, prev) {

    // We only care about links on boundaries
    if (prev && (prev.length > 0)) {
      var last = prev[prev.length - 1];
      if (typeof last === "string" && (!last.match(/\s$/))) { return; }
    }

    var pattern = /(^|\s)((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
        m = pattern.exec(text);

    if (m) {
      var url = m[2],
          displayUrl = m[2];

      if (url.match(/^www/)) { url = "http://" + url; }
      return [m[0].length, ['a', {href: url}, displayUrl]];
    }

  };


});