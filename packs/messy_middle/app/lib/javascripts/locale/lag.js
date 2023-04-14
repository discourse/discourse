MessageFormat.locale.lag = function (n) {
  if (n === 0) {
    return 'zero';
  }
  if (n > 0 && n < 2) {
    return 'one';
  }
  return 'other';
};
