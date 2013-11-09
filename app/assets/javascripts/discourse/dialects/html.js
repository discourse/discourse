/**
  If a row begins with HTML tags, don't parse it.
**/
var blockTags = ['address', 'article', 'aside', 'audio', 'blockquote', 'canvas', 'dd', 'div',
                 'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
                 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'noscript', 'ol', 'output',
                 'p', 'pre', 'section', 'table', 'tfoot', 'ul', 'video'],

    splitAtLast = function(tag, block, next, first) {
      var endTag = "</" + tag + ">",
          endTagIndex = first ? block.indexOf(endTag) : block.lastIndexOf(endTag);

      if (endTagIndex !== -1) {
        endTagIndex += endTag.length;

        var leading = block.substr(0, endTagIndex),
            trailing = block.substr(endTagIndex).replace(/^\s+/, '');

        if (trailing.length) {
          next.unshift(trailing);
        }

        return [ leading ];
      }
    };

Discourse.Dialect.registerBlock('html', function(block, next) {

  // Fix manual blockquote paragraphing even though it's not strictly correct
  var split = splitAtLast('blockquote', block, next, true);
  if (split) { return split; }

  var m = /^<([^>]+)\>/m.exec(block);
  if (m && m[1]) {
    var tag = m[1].split(/\s/);
    if (tag && tag[0] && blockTags.indexOf(tag[0]) !== -1) {
      split = splitAtLast(tag[0], block, next);
      if (split) { return split; }
      return [ block.toString() ];
    }
  }
});