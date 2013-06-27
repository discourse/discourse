MessageFormat.locale.br = function (n) {
  if (n === 0) {
    return 'zero';
  }
  if (n == 1) {
    return 'one';
  }
  if (n == 2) {
    return 'two';
  }
  if (n == 3) {
    return 'few';
  }
  if (n == 6) {
    return 'many';
  }
  return 'other';
};
