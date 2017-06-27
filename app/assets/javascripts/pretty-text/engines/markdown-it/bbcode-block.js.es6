let isWhiteSpace;

function trailingSpaceOnly(src, start, max) {
  let i;
  for(i=start;i<max;i++) {
    let code = src.charCodeAt(i);
    if (code === 0x0A) { return true; }
    if (!isWhiteSpace(code)) { return false; }
  }

  return true;
}

// parse a tag [test a=1 b=2] to a data structure
// {tag: "test", attrs={a: "1", b: "2"}
export function parseBBCodeTag(src, start, max, multiline) {

  let i;
  let tag;
  let attrs = {};
  let closed = false;
  let length = 0;
  let closingTag = false;

  // closing tag
  if (src.charCodeAt(start+1) === 47) {
    closingTag = true;
    start += 1;
  }

  for (i=start+1;i<max;i++) {
    let letter = src[i];
    if (!( (letter >= 'a' && letter <= 'z') ||
         (letter >= 'A' && letter <= 'Z'))) {
      break;
    }
  }

  tag = src.slice(start+1, i);

  if (!tag) {
    return;
  }

  if (closingTag) {
    if (src[i] === ']') {

      if (multiline && !trailingSpaceOnly(src, i+1, max)) {
        return;
      }

      return {tag, length: tag.length+3, closing: true};
    }
    return;
  }

  for (;i<max;i++) {
    let letter = src[i];

    if (letter === ']') {
      closed = true;
      break;
    }
  }

  if (closed) {
    length = (i-start)+1;

    let raw = src.slice(start+tag.length+1, i);

    // trivial parser that is going to have to be rewritten at some point
    if (raw) {

      // reading a key 0, reading a val = 1
      let readingKey = true;
      let startSplit = 0;
      let key;

      for(i=0; i<raw.length; i++) {
        if (raw[i] === '=' || i === (raw.length-1)) {
          // one more offset to allow room to capture last
          if (raw[i] !== '=' || i === (raw.length-1)) {
            i+=1;
          }

          let cur = raw.slice(startSplit, i).trim();
          if (readingKey) {
            key =  cur || '_default';
          } else {
            let val = raw.slice(startSplit, i).trim();
            if (val && val.length > 0) {
              val = val.replace(/^["'](.*)["']$/, '$1');
              attrs[key] = val;
            }
          }
          readingKey = !readingKey;
          startSplit = i+1;
        }
      }
    }

    if (multiline && !trailingSpaceOnly(src, start+length, max)) {
      return;
    }

    tag = tag.toLowerCase();

    return {tag, attrs, length};
  }
}

function applyBBCode(state, startLine, endLine, silent, md) {

  var i, nextLine,
      old_parent, old_line_max, rule,
      start = state.bMarks[startLine] + state.tShift[startLine],
      initial = start,
      max = state.eMarks[startLine];

  // [ === 91
  if (91 !== state.src.charCodeAt(start)) { return false; }

  let info = parseBBCodeTag(state.src, start, max, true);

  if (!info || info.closing) {
    return false;
  }

  let rules = md.block.bbcode_ruler.getRules();

  for(i=0;i<rules.length;i++) {
    let r = rules[i].rule;

    if (r.tag === info.tag) {
      rule = r;
      break;
    }
  }

  if (!rule) { return false; }

  // Since start is found, we can report success here in validation mode
  if (silent) { return true; }

  // Search for the end of the block
  nextLine = startLine;

  let closeTag;
  let nesting = 0;

  for (;;) {
    nextLine++;
    if (nextLine >= endLine) {
      // unclosed bbcode block should not be autoclosed by end of document.
      return false;
    }

    start = state.bMarks[nextLine] + state.tShift[nextLine];
    max = state.eMarks[nextLine];

    if (start < max && state.sCount[nextLine] < state.blkIndent) {
      // non-empty line with negative indent should stop the list:
      // - ```
      //  test
      break;
    }


    // bbcode close [ === 91
    if (91 !== state.src.charCodeAt(start)) { continue; }

    if (state.sCount[nextLine] - state.blkIndent >= 4) {
      // closing fence should be indented less than 4 spaces
      continue;
    }

    closeTag = parseBBCodeTag(state.src, start, max, true);

    if (closeTag && closeTag.closing && closeTag.tag === info.tag) {
      if (nesting === 0) {
        break;
      }
      nesting--;
    }

    if (closeTag && !closeTag.closing && closeTag.tag === info.tag) {
      nesting++;
    }

    closeTag = null;
  }

  if (!closeTag) {
    return false;
  }

  old_parent = state.parentType;
  old_line_max = state.lineMax;

  // this will prevent lazy continuations from ever going past our end marker
  state.lineMax = nextLine;

  if (rule.before) {
    rule.before.call(this, state, info.attrs, md, state.src.slice(initial, initial + info.length + 1));
  }

  let wrapTag;
  if (rule.wrap) {
    let split = rule.wrap.split('.');
    wrapTag = split[0];
    let className = split.slice(1).join(' ');

    let token = state.push('wrap_bbcode', wrapTag, 1);

    if (className) {
      token.attrs = [['class', className]];
    }
  }

  let lastToken = state.tokens[state.tokens.length-1];
  lastToken.map    = [ startLine, nextLine ];

  state.md.block.tokenize(state, startLine + 1, nextLine);

  if (rule.wrap) {
    state.push('wrap_bbcode', wrapTag, -1);
  }

  if (rule.after) {
    rule.after.call(this, state, lastToken, md);
  }

  lastToken = state.tokens[state.tokens.length-1];

  state.parentType = old_parent;
  state.lineMax = old_line_max;
  state.line = nextLine+1;

  return true;
}

export function setup(helper) {
  if (!helper.markdownIt) { return; }

  helper.registerPlugin(md => {
    isWhiteSpace = md.utils.isWhiteSpace;
    md.block.ruler.after('fence', 'bbcode', (state, startLine, endLine, silent)=> {
      return applyBBCode(state, startLine, endLine, silent, md);
    }, { alt: ['paragraph', 'reference', 'blockquote', 'list'] });
  });
}
