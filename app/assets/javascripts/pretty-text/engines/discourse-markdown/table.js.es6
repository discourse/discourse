import { registerOption } from 'pretty-text/pretty-text';

function tableFlattenBlocks(blocks) {
  let result = "";

  blocks.forEach(b => {
    result += b;
    if (b.trailing) { result += b.trailing; }
  });

  // bypass newline insertion
  return result.replace(/[\n\r]/g, " ");
};

registerOption((siteSettings, opts) => {
  opts.features.table = !!siteSettings.allow_html_tables;
});

export function setup(helper) {

  helper.whiteList(['table', 'table.md-table', 'tbody', 'thead', 'tr', 'th', 'td']);

  helper.replaceBlock({
    start: /(<table[^>]*>)([\S\s]*)/igm,
    stop: /<\/table>/igm,
    rawContents: true,
    priority: 1,

    emitter(contents) {
      return ['table', {"class": "md-table"}, tableFlattenBlocks.apply(this, [contents])];
    }
  });
}
