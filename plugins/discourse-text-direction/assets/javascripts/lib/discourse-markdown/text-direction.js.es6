import { registerOption } from 'pretty-text/pretty-text';

registerOption((siteSettings, opts) => {
  opts.features["text-direction"] = true;
});

function setTextDirection(text) {
  while (text != (text = text.replace(/\[text-direction=(\w*)\]((?:(?!\[text-direction=(\w*)\]|\[\/text-direction\])[\S\s])*)\[\/text-direction\]/ig, function (match, p1, p2, offset, string) {
    let dirClass;
    if (p1 === 'rtl') {
      dirClass = 'tmp-rtl';
    } else if (p1 === 'ltr') {
      dirClass = 'tmp-ltr';
    }
    return '<div class="' + dirClass + '">' + p2 + '</div>';
  })));
  return text;
}

export function setup(helper) {
  helper.whiteList(['div.tmp-rtl', 'div.tmp-ltr']);
  helper.addPreProcessor(text => setTextDirection(text));
}
