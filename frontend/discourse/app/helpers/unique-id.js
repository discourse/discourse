// https://github.com/emberjs/ember.js/blob/master/packages/@ember/-internals/glimmer/lib/helpers/unique-id.ts
export default function uniqueId() {
  return ([3e7] + -1e3 + -4e3 + -2e3 + -1e11).replace(
    /[0-3]/g,
    (a) =>
      /* eslint-disable no-bitwise */
      ((a * 4) ^ ((Math.random() * 16) >> (a & 2))).toString(16)
    /* eslint-enable no-bitwise */
  );
}
