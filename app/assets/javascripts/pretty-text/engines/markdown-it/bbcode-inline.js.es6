import { parseBBCodeTag } from 'pretty-text/engines/markdown-it/bbcode-block';

const rules = {
  'b': {tag: 'span', 'class': 'bbcode-b'},
  'i': {tag: 'span', 'class': 'bbcode-i'},
  'u': {tag: 'span', 'class': 'bbcode-u'},
  's': {tag: 'span', 'class': 'bbcode-s'}
};

function tokanizeBBCode(state, silent) {

  let pos = state.pos;

  // 91 = [
  if (silent || state.src.charCodeAt(pos) !== 91) {
    return false;
  }

  const tagInfo = parseBBCodeTag(state.src, pos, state.posMax);

  if (!tagInfo) {
    return false;
  }

  const rule = rules[tagInfo.tag];
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

    token = state.tokens[startDelim.token];
    token.type = 'bbcode_' + tagInfo.tag + '_open';
    token.attrs = [['class', tagInfo.rule['class']]];
    token.tag = tagInfo.rule.tag;
    token.nesting = 1;
    token.markup = token.content;
    token.content = '';

    token = state.tokens[endDelim.token];
    token.type = 'bbcode_' + tagInfo.tag + '_close';
    token.tag = tagInfo.rule.tag;
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
    md.inline.ruler.push('bbcode-inline', tokanizeBBCode);
    md.inline.ruler2.before('text_collapse', 'bbcode-inline', processBBCode);
  });
}
