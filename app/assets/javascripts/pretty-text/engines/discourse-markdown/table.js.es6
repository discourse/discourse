export function setup(helper) {
  // this is built in now
  // TODO: sanitizer needs fixing, does not properly support this yet

  // we need a custom callback for style handling
  helper.whiteList({
    custom: function(tag,attr,val) {
      if (tag !== 'th' && tag !== 'td') {
        return false;
      }

      if (attr !== 'style') {
        return false;
      }

      return (val === 'text-align:right' || val === 'text-align:left' || val === 'text-align:center');
    }
  });

  helper.whiteList([
      'table',
      'tbody',
      'thead',
      'tr',
      'th',
      'td',
  ]);
}
