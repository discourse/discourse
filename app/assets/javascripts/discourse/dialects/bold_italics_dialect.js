/**
  markdown-js doesn't ensure that em/strong codes are present on word boundaries.
  So we create our own handlers here.
**/

// Support for simultaneous bold and italics
Discourse.Dialect.inlineBetween({
  between: '***',
  wordBoundary: true,
  emitter: function(contents) { return ['strong', ['em'].concat(contents)]; }
});

// Builds a common markdown replacer
var replaceMarkdown = function(match, tag) {
  Discourse.Dialect.inlineBetween({
    between: match,
    wordBoundary: true,
    emitter: function(contents) { return [tag].concat(contents) }
  });
};

replaceMarkdown('**', 'strong');
replaceMarkdown('__', 'strong');
replaceMarkdown('*', 'em');
replaceMarkdown('_', 'em');


// There's a weird issue with the markdown parser where it won't process simple blockquotes
// when they are prefixed with spaces. This fixes it.
Discourse.Dialect.on("register", function(event) {
  var dialect = event.dialect,
      MD = event.MD;

  dialect.block["fix_simple_quotes"] = function(block, next) {
    var m = /^ +(\>[\s\S]*)/.exec(block);
    if (m && m[1] && m[1].length) {
      next.unshift(MD.mk_block(m[1]));
      return [];
    }
  };

});