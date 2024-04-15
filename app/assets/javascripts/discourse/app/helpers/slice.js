export default function slice(...args) {
  let array = args.pop();
  if (array instanceof Function) {
    array = array.call();
  }
  if (!Array.isArray(array) || array.length === 0) {
    return [];
  }
  return array.slice(...args);
}
