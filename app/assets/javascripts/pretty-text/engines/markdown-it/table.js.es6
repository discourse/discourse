export function setup(helper) {

  if (!helper.markdownIt) { return; }

  // this is built in now
  // TODO: sanitizer needs fixing, does not properly support this yet
  helper.whiteList([
      'table',
      'th[style=text-align:right]',
      'th[style=text-align:left]',
      'th[style=text-align:center]',
      'tbody',
      'thead',
      'tr',
      'th',
      'td',
      'td[style=text-align:right]',
      'td[style=text-align:left]',
      'td[style=text-align:center]'
  ]);
}
