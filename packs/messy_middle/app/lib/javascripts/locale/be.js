MessageFormat.locale.be = function (n) {
  var r10 = n % 10, r100 = n % 100;

  if (r10 == 1 && r100 != 11)
    return 'one';

  if (r10 >= 2 && r10 <= 4 && (r100 < 12 || r100 > 14) && n == Math.floor(n))
    return 'few';

  if ((r10 == 0 || (r10 >= 5 && r10 <= 9) || (r100 >= 11 && r100 <= 14)) && n == Math.floor(n))
    return 'many';

  return 'other';
};
