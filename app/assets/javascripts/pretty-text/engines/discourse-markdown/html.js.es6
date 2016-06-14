const BLOCK_TAGS = ['address', 'article', 'aside', 'audio', 'blockquote', 'canvas', 'dd', 'div',
                    'dl', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3',
                    'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'iframe', 'noscript', 'ol', 'output',
                    'p', 'pre', 'section', 'table', 'tfoot', 'ul', 'video'];

function splitAtLast(tag, block, next, first) {
  const endTag = `</${tag}>`;
  let endTagIndex = first ? block.indexOf(endTag) : block.lastIndexOf(endTag);

  if (endTagIndex !== -1) {
    endTagIndex += endTag.length;

    const trailing = block.substr(endTagIndex).replace(/^\s+/, '');
    if (trailing.length) {
      next.unshift(trailing);
    }

    return [ block.substr(0, endTagIndex) ];
  }
};

export function setup(helper) {

  // If a row begins with HTML tags, don't parse it.
  helper.registerBlock('html', function(block, next) {
    let split, pos;

    // Fix manual blockquote paragraphing even though it's not strictly correct
    // PERF NOTE: /\S+<blockquote/ is a perf hog for search, try on huge string
    if (pos = block.search(/<blockquote/) >= 0) {
      if(block.substring(0, pos).search(/\s/) === -1) {
        split = splitAtLast('blockquote', block, next, true);
        if (split) { return this.processInline(split[0]); }
      }
    }

    const m = /^<([^>]+)\>/.exec(block);
    if (m && m[1]) {
      const tag = m[1].split(/\s/);
      if (tag && tag[0] && BLOCK_TAGS.indexOf(tag[0]) !== -1) {
        split = splitAtLast(tag[0], block, next);
        if (split) {
          if (split.length === 1 && split[0] === block) { return; }
          return split;
        }
        return [ block.toString() ];
      }
    }
  });
}
