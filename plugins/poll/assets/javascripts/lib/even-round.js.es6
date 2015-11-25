// stolen from http://stackoverflow.com/a/13484088/11983
export default (percentages) => {
  const sumOfDecimals = Math.ceil(percentages.map(a => a % 1).reduce((a, b) => a + b));
  // compensate error by adding 1 to the first n items
  for (let i = 0; i < sumOfDecimals; i++) {
    percentages[i] = ++percentages[i];
  }
  return percentages.map(a => Math.floor(a));
};
