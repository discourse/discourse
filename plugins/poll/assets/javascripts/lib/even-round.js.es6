// stolen from http://stackoverflow.com/a/13485888/11983
export default (percentages) => {
  const off = 100 - _.reduce(percentages, (acc, x) => acc + Math.round(x), 0);
  return _.chain(percentages)
          .sortBy(x => Math.round(x) - x)
          .map((x, i) => Math.round(x) + (off > i) - (i >= (percentages.length + off)))
          .value();
};
