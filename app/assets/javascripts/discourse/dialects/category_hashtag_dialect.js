/**
  Supports Discourse's category hashtags (#category-slug) for automatically
  generating a link to the category.
**/
Discourse.Dialect.inlineRegexp({
  start: '#',
  matcher: /^#([\w-:]{1,101})/i,
  spaceOrTagBoundary: true,

  emitter: function(matches) {
    var slug = matches[1],
        hashtag = matches[0],
        attributeClass = 'hashtag',
        categoryHashtagLookup = this.dialect.options.categoryHashtagLookup,
        result = categoryHashtagLookup && categoryHashtagLookup(slug);

    if (result) {
      return ['a', { class: attributeClass, href: result[0] }, '#', ["span", {}, result[1]]];
    } else {
      return ['span', { class: attributeClass }, hashtag];
    }
  }
});
