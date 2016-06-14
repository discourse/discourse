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
  return text.replace(/<\/summary>/ig, "</summary>\n\n").replace(/<\/details>/ig, "\n\n</details>\n\n");
}

registerOption((siteSettings, opts) => {
  opts.features.details = true;
});

export function setup(helper) {
  helper.whiteList('details.elided');
  helper.addPreProcessor(text => replaceDetails(text));
}
