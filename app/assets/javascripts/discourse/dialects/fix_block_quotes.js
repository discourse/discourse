// There's a weird issue with the markdown parser where it won't process simple blockquotes
// when they are prefixed with spaces. This fixes it.
Discourse.Dialect.on("register", function(event) {
  var dialect = event.dialect,
      MD = event.MD;

  dialect.block["fix_block_quotes"] = function(block, next) {
    var m = /(^|\n) +(\>[\s\S]*)/.exec(block);
    if (m && m[2] && m[2].length) {
      var blockContents = block.replace(/(^|\n) +\>/, "$1>");
      next.unshift(blockContents);
      return [];
    }
  };

});