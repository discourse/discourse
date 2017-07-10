import { textReplace } from 'pretty-text/engines/markdown-it/helpers';

function addHashtag(buffer, matches, state) {
  const options = state.md.options.discourse;
  const [hashtag, slug] = matches;
  const categoryHashtagLookup = options.categoryHashtagLookup;
  const result = categoryHashtagLookup && categoryHashtagLookup(slug);

  let token;

  if (result) {
    token = new state.Token('link_open', 'a', 1);
    token.attrs = [['class', 'hashtag'], ['href', result[0]]];
    token.block = false;
    buffer.push(token);

    token = new state.Token('text', '', 0);
    token.content = '#';
    buffer.push(token);

    token = new state.Token('span_open', 'span', 1);
    token.block = false;
    buffer.push(token);

    token = new state.Token('text', '', 0);
    token.content = result[1];
    buffer.push(token);

    buffer.push(new state.Token('span_close', 'span', -1));

    buffer.push(new state.Token('link_close', 'a', -1));
  } else {

    token = new state.Token('span_open', 'span', 1);
    token.attrs = [['class', 'hashtag']];
    buffer.push(token);

    token = new state.Token('text', '', 0);
    token.content = hashtag;
    buffer.push(token);

    token = new state.Token('span_close', 'span', -1);
    buffer.push(token);
  }
}

const REGEX = /#([\w-:]{1,101})/gi;

function allowedBoundary(content, index, utils) {
  let code = content.charCodeAt(index);
  return (utils.isWhiteSpace(code) || utils.isPunctChar(String.fromCharCode(code)));
}

function applyHashtag(content, state) {
  let result = null,
      match,
      pos = 0;

  while (match = REGEX.exec(content)) {
    // check boundary
    if (match.index > 0) {
      if (!allowedBoundary(content, match.index-1, state.md.utils)) {
        continue;
      }
    }

    // check forward boundary as well
    if (match.index + match[0].length < content.length) {
      if (!allowedBoundary(content, match.index + match[0].length, state.md.utils)) {
        continue;
      }
    }

    if (match.index > pos) {
      result = result || [];
      let token = new state.Token('text', '', 0);
      token.content = content.slice(pos, match.index);
      result.push(token);
    }

    result = result || [];
    addHashtag(result, match, state);

    pos = match.index + match[0].length;
  }

  if (result && pos < content.length) {
    let token = new state.Token('text', '', 0);
    token.content = content.slice(pos);
    result.push(token);
  }

  return result;
}

export function setup(helper) {

  if (!helper.markdownIt) { return; }

  helper.registerPlugin(md=>{

    md.core.ruler.push('category-hashtag', state => textReplace(
      state, applyHashtag, true /* skip all links */
    ));
  });
}
