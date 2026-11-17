// https://github.com/emberjs/ember.js/blob/master/packages/@ember/-internals/glimmer/lib/helpers/unique-id.ts
/**
 * Returns a random version 4 UUID.
 *
 * @returns The UUID.
 */
export default function dUniqueId(): string {
  // The array coerces to a string, giving the template
  // "30000000-1000-4000-2000-100000000000". Each digit from 0 to 3 is replaced by a
  // random hex digit, and the arithmetic coerces that digit back to a number.
  return (([3e7] as unknown as string) + -1e3 + -4e3 + -2e3 + -1e11).replace(
    /[0-3]/g,
    (a) =>
      /* eslint-disable no-bitwise */
      (
        ((a as unknown as number) * 4) ^
        ((Math.random() * 16) >> ((a as unknown as number) & 2))
      ).toString(16)
    /* eslint-enable no-bitwise */
  );
}
