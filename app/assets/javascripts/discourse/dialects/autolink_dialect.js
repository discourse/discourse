/**
  This addition handles auto linking of text. When included, it will parse out links and create
  a hrefs for them.
**/
var urlReplacerArgs = {
  matcher: /(^|\s)((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
  spaceBoundary: true,

  emitter: function(matches) {
    var url = matches[2],
        displayUrl = url;

    if (url.match(/^www/)) { url = "http://" + url; }
    return ['a', {href: url}, displayUrl];
  }
};

Discourse.Dialect.inlineRegexp(_.merge({start: 'http'}, urlReplacerArgs));
Discourse.Dialect.inlineRegexp(_.merge({start: 'www'}, urlReplacerArgs));
