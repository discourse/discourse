/*eslint no-bitwise:0 */

// http://stackoverflow.com/a/8809472/17174
/**
 * Generates a random version 4 UUID.
 *
 * @returns A UUID string such as `3b241101-e2bb-4255-8caf-4136c566a962`.
 */
export default function (): string {
  let d = new Date().getTime();
  if (window.performance && typeof window.performance.now === "function") {
    d += performance.now(); //use high-precision timer if available
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(
    /[xy]/g,
    function (c: string) {
      const r = ((d + Math.random() * 16) % 16) | 0;
      d = Math.floor(d / 16);
      return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
    }
  );
}
