const regex = /^(\w[\w.-]{0,59})\b/i;

function applyMentions(state, silent, isWhiteSpace, isPunctChar, mentionLookup, getURL) {

  let pos = state.pos;

  // 64 = @
  if (silent || state.src.charCodeAt(pos) !== 64) {
    return false;
  }

  if (pos > 0) {
    let prev = state.src.charCodeAt(pos-1);
    if (!isWhiteSpace(prev) && !isPunctChar(String.fromCharCode(prev))) {
      return false;
    }
  }

  // skip if in a link
  if (state.tokens) {
    let last = state.tokens[state.tokens.length-1];
    if (last) {
      if (last.type === 'link_open') {
        return false;
      }
      if (last.type === 'html_inline' && last.content.substr(0,2) === "<a") {
        return false;
      }
    }
  }

  let maxMention = state.src.substr(pos+1, 60);

  let matches = maxMention.match(regex);

  if (!matches) {
    return false;
  }

  let username = matches[1];

  let type = mentionLookup && mentionLookup(username);

  let tag = 'a';
  let className = 'mention';
  let href = null;

  if (type === 'user') {
    href = getURL('/u/') + username.toLowerCase();
  } else if (type === 'group') {
    href = getURL('/groups/') + username;
    className = 'mention-group';
  } else {
    tag = 'span';
  }

  let token = state.push('mention_open', tag, 1);
  token.attrs = [['class', className]];
  if (href) {
    token.attrs.push(['href', href]);
  }

  token = state.push('text', '', 0);
  token.content = '@'+username;

  state.push('mention_close', tag, -1);

  state.pos = pos + username.length + 1;

  return true;
}

export function setup(helper) {

  if (!helper.markdownIt) { return; }

  helper.registerPlugin(md => {
    md.inline.ruler.push('mentions', (state,silent)=> applyMentions(
          state,
          silent,
          md.utils.isWhiteSpace,
          md.utils.isPunctChar,
          md.options.discourse.mentionLookup,
          md.options.discourse.getURL
    ));
  });
}

