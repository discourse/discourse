// stolen from http://stackoverflow.com/a/13484088/11983
function sumsUpTo100(percentages) {
  return percentages.map(p => Math.floor(p)).reduce((a, b) => a + b) === 100;
}

export default (percentages) => {
  const sumOfDecimals = Math.ceil(percentages.map(a => a % 1).reduce((a, b) => a + b));
  // compensate error by adding 1 to the first n "non-zero" items
  for (let i = 0, max = percentages.length; i < sumOfDecimals && i < max; i++) {
    if (percentages[i] > 0) {
      percentages[i] = ++percentages[i];
      // quit early when there is a rounding issue
      if (sumsUpTo100(percentages)) break;
    }
  }
  return percentages.map(p => Math.floor(p));
};
