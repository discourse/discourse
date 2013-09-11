/**
  If a row begins with HTML tags, don't parse it.
**/
Discourse.Dialect.registerBlock('html', function(block, next) {
  if (block.match(/^<[^>]+\>/)) {
    return [ block.toString() ];
  }
});