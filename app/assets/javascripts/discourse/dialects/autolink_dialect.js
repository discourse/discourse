/**
  This addition handles auto linking of text. When included, it will parse out links and create
  a hrefs for them.
**/
var urlReplacerArgs = {
  matcher: /^((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/,
  spaceOrTagBoundary: true,

  emitter: function(matches) {
    var url = matches[1],
        displayUrl = url;

    // Don't autolink a markdown link to something
    if (url.match(/\]\[\d$/)) { return; }

    // If we improperly caught a markdown link abort
    if (url.match(/\(http/)) { return; }

    if (url.match(/^www/)) { url = "http://" + url; }
    return ['a', {href: url}, displayUrl];
  }
};

Discourse.Dialect.inlineRegexp(_.merge({start: 'http'}, urlReplacerArgs));
Discourse.Dialect.inlineRegexp(_.merge({start: 'www'}, urlReplacerArgs));
