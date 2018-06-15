/*eslint no-bitwise:0 */

// Note: before changing this be aware the same algo is used server side for avatars.
export function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}
