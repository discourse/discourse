/**
 * Joins the truthy class names, flattening arrays one level deep.
 *
 * @param args - The class names, falsy values and arrays of them.
 * @returns The classes separated by spaces, or `undefined` when none are left, so a bound
 *   `class` attribute is left out.
 */
export default function dConcatClass(...args: unknown[]): string | undefined {
  const classes = args.flat().filter(Boolean).join(" ");

  if (classes.length) {
    return classes;
  }
}
