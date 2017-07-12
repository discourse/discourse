import { registerOption } from 'pretty-text/pretty-text';

function insertDetails(_, summary, details) {
  return `<details><summary>${summary}</summary>${details}</details>`;
}

// replace all [details] BBCode with HTML 5.1 equivalent
function replaceDetails(text) {
  text = text || "";

  while (text !== (text = text.replace(/\[details=([^\]]+)\]((?:(?!\[details=[^\]]+\]|\[\/details\])[\S\s])*)\[\/details\]/ig, insertDetails)));

  // add new lines to make sure we *always* have a <p> element after </summary> and around </details>
  // otherwise we can't hide the content since we can't target text nodes via CSS
  return text.replace(/<\/summary>/ig, "</summary>\n\n")
             .replace(/<\/details>/ig, "\n\n</details>\n\n");
}

registerOption((siteSettings, opts) => {
  opts.features.details = true;
});

const rule = {
  tag: 'details',
  before: function(state, attrs) {
    state.push('bbcode_open', 'details', 1);
    state.push('bbcode_open', 'summary', 1);

    let token = state.push('text', '', 0);
    token.content = attrs['_default'] || '';

    state.push('bbcode_close', 'summary', -1);
  },

  after: function(state) {
    state.push('bbcode_close', 'details', -1);
  }
};

export function setup(helper) {
  helper.whiteList([
    'summary',
    'summary[title]',
    'details',
    'details[open]',
    'details.elided'
  ]);

  if (helper.markdownIt) {
    helper.registerPlugin(md => {
      md.block.bbcode_ruler.push('details', rule);
    });
  } else {
    helper.addPreProcessor(text => replaceDetails(text));
  }
}
