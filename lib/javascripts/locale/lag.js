 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
MessageFormat.locale.lag = function (n) {
  if (n === 0) {
    return 'zero';
  }
  if (n > 0 && n < 2) {
    return 'one';
  }
  return 'other';
};
//@license-end
