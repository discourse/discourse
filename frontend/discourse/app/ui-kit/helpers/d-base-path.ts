import getUrl from "discourse/lib/get-url";

/**
 * Returns the site's base path, such as `"/forum"`, or `""` without one.
 *
 * @returns The base path.
 */
export default function dBasePath(): string {
  return getUrl("");
}
