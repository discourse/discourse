import { parseBBCodeTag } from 'pretty-text/engines/markdown-it/bbcode-block';

function tokanizeBBCode(state, silent, ruler) {

  let pos = state.pos;

  // 91 = [
  if (silent || state.src.charCodeAt(pos) !== 91) {
    return false;
  }

  const tagInfo = parseBBCodeTag(state.src, pos, state.posMax);

  if (!tagInfo) {
    return false;
  }

  let rules = ruler.getRules();
  let rule;

  for (let i=0; i<rules.length; i++) {
    let r = rules[i].rule;
    if (r.tag === tagInfo.tag) {
      rule = r;
      break;
    }
  }

  if (!rule) {
    return false;
  }

  tagInfo.rule = rule;

  let token = state.push('text', '' , 0);
  token.content = state.src.slice(pos, pos+tagInfo.length);

  state.delimiters.push({
    bbInfo: tagInfo,
    marker: 'bb' + tagInfo.tag,
    open: !tagInfo.closing,
    close: !!tagInfo.closing,
    token: state.tokens.length - 1,
    level: state.level,
    end: -1,
    jump: 0
  });

  state.pos = pos + tagInfo.length;
  return true;
}

function processBBCode(state, silent) {
  let i,
      startDelim,
      endDelim,
      token,
      tagInfo,
      delimiters = state.delimiters,
      max = delimiters.length;

  if (silent) {
    return;
  }

  for (i=0; i<max-1; i++) {
    startDelim = delimiters[i];
    tagInfo = startDelim.bbInfo;

    if (!tagInfo) {
      continue;
    }

    if (startDelim.end === -1) {
      continue;
    }

    endDelim = delimiters[startDelim.end];

    let split = tagInfo.rule.wrap.split('.');
    let tag = split[0];
    let className = split.slice(1).join(' ');

    token = state.tokens[startDelim.token];

    token.type = 'bbcode_' + tagInfo.tag + '_open';
    token.tag = tag;
    if (className) {
      token.attrs = [['class', className]];
    }
    token.nesting = 1;
    token.markup = token.content;
    token.content = '';

    token = state.tokens[endDelim.token];
    token.type = 'bbcode_' + tagInfo.tag + '_close';
    token.tag = tag;
    token.nesting = -1;
    token.markup = token.content;
    token.content = '';
  }
  return false;
}

export function setup(helper) {

  if (!helper.markdownIt) { return; }

  helper.whiteList(['span.bbcode-b', 'span.bbcode-i', 'span.bbcode-u', 'span.bbcode-s']);

  helper.registerOptions(opts => {
    opts.features['bbcode-inline'] = true;
  });

  helper.registerPlugin(md => {
    const ruler = md.inline.bbcode_ruler;

    md.inline.ruler.push('bbcode-inline', (state,silent) => tokanizeBBCode(state,silent,ruler));
    md.inline.ruler2.before('text_collapse', 'bbcode-inline', processBBCode);

    ruler.push('bold', {
      tag: 'b',
      wrap: 'span.bbcode-b',
    });

    ruler.push('italic', {
      tag: 'i',
      wrap: 'span.bbcode-i'
    });

    ruler.push('underline', {
      tag: 'u',
      wrap: 'span.bbcode-u'
    });

    ruler.push('strike', {
      tag: 's',
      wrap: 'span.bbcode-s'
    });
  });
}
