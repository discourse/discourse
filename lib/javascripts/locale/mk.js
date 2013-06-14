MessageFormat.locale.mk = function (n) {
  if ((n % 10) == 1 && n != 11) {
    return 'one';
  }
  return 'other';
};
