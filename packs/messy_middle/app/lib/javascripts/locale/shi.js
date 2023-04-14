MessageFormat.locale.shi = function(n) {
  if (n >= 0 && n <= 1) {
    return 'one';
  }
  if (n >= 2 && n <= 10 && n == Math.floor(n)) {
    return 'few';
  }
  return 'other';
};
