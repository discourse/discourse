/**
  If a row begins with HTML tags, don't parse it.
**/
var blockTags = ['address', 'article', 'aside', 'audio', 'blockquote', 'canvas', 'dd', 'div',
                 'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
                 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'iframe', 'noscript', 'ol', 'output',
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
  var split, pos;

  // Fix manual blockquote paragraphing even though it's not strictly correct
  // PERF NOTE: /\S+<blockquote/ is a perf hog for search, try on huge string
  if (pos = block.search(/<blockquote/) >= 0) {
    if(block.substring(0, pos).search(/\s/) === -1) {
      split = splitAtLast('blockquote', block, next, true);
      if (split) { return this.processInline(split[0]); }
    }
  }

  var m = /^<([^>]+)\>/.exec(block);
  if (m && m[1]) {
    var tag = m[1].split(/\s/);
    if (tag && tag[0] && blockTags.indexOf(tag[0]) !== -1) {
      split = splitAtLast(tag[0], block, next);
      if (split) {
        if (split.length === 1 && split[0] === block) { return; }
        return split;
      }
      return [ block.toString() ];
    }
  }
});
