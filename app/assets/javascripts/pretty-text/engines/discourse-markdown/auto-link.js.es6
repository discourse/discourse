//  This addition handles auto linking of text. When included, it will parse out links and create
//  `<a href>`s for them.

const urlReplacerArgs = {
  matcher: /^((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/,
  spaceOrTagBoundary: true,

  emitter(matches) {
    const url = matches[1];
    let href = url;

    // Don't autolink a markdown link to something
    if (url.match(/\]\[\d$/)) { return; }

    // If we improperly caught a markdown link abort
    if (url.match(/\(http/)) { return; }

    if (url.match(/^www/)) { href = "http://" + url; }
    return ['a', { href }, url];
  }
};

export function setup(helper) {
  helper.inlineRegexp(_.merge({start: 'http'}, urlReplacerArgs));
  helper.inlineRegexp(_.merge({start: 'www'}, urlReplacerArgs));
}
