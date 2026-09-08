export function humanKeyName(code) {
  if (code.startsWith("Key")) {
    return code.slice(3);
  }
  if (code.startsWith("Digit")) {
    return code.slice(5);
  }
  if (code.startsWith("Numpad")) {
    return "Num " + code.slice(6);
  }
  return code.replace(/([a-z])([A-Z])/g, "$1 $2");
}
