/**
  If a row begins with HTML tags, don't parse it.
**/
var blockTags = ['address', 'article', 'aside', 'audio', 'blockquote', 'canvas', 'dd', 'div',
                 'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
                 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'noscript', 'ol', 'output',
                 'p', 'pre', 'section', 'table', 'tfoot', 'ul', 'video'];

Discourse.Dialect.registerBlock('html', function(block, next) {

  var m = /^<([^>]+)\>/.exec(block);
  if (m && m[1]) {
    var tag = m[1].split(/\s/);
    if (tag && tag[0] && blockTags.indexOf(tag[0]) !== -1) {
      return [ block.toString() ];
    }
  }
});