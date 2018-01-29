const ltrChars = 'A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590\u0800-\u1FFF\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF';
const rtlChars = '\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC';

export function isRTL(text) {
  const rtlDirCheck = new RegExp('^[^'+ltrChars+']*['+rtlChars+']');

  return rtlDirCheck.test(text);
}

export function isLTR(text) {
  const ltrDirCheck = new RegExp('^[^'+rtlChars+']*['+ltrChars+']');

  return ltrDirCheck.test(text);
}

export function setTextDirections($elem) {
  $elem.find('*').each((i, e) => {
    let $e = $(e),
      textContent = $e.text();
    if (textContent) {
      isRTL(textContent) ? $e.attr('dir', 'rtl') : $e.attr('dir', 'ltr');
    }
  });
}

export function siteDir() {
  return $('html').hasClass('rtl') ? 'rtl' : 'ltr';
}
