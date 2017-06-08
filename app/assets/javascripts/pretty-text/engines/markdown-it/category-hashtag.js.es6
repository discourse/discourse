import { inlineRegexRule } from 'pretty-text/engines/markdown-it/helpers';

function emitter(matches, state) {
    const options = state.md.options.discourse;
    const [hashtag, slug] = matches;
    const categoryHashtagLookup = options.categoryHashtagLookup;
    const result = categoryHashtagLookup && categoryHashtagLookup(slug);

    let token;

    if (result) {
      token = state.push('link_open', 'a', 1);
      token.attrs = [['class', 'hashtag'], ['href', result[0]]];
      token.block = false;

      token = state.push('text', '', 0);
      token.content = '#';

      token = state.push('span_open', 'span', 1);
      token.block = false;

      token = state.push('text', '', 0);
      token.content = result[1];

      state.push('span_close', 'span', -1);

      state.push('link_close', 'a', -1);
    } else {

      token = state.push('span_open', 'span', 1);
      token.attrs = [['class', 'hashtag']];

      token = state.push('text', '', 0);
      token.content = hashtag;

      token = state.push('span_close', 'span', -1);
    }

    return true;
}

export function setup(helper) {

  if (!helper.markdownIt) { return; }

  helper.registerPlugin(md=>{

    const rule = inlineRegexRule(md, {
      start: '#',
      matcher: /^#([\w-:]{1,101})/i,
      skipInLink: true,
      maxLength: 102,
      emitter: emitter
    });

    md.inline.ruler.push('category-hashtag', rule);
  });
}
