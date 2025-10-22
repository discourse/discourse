import truthConvert from "../utils/truth-convert";

export default function and(...args) {
  let arg = false;

  for (arg of args) {
    if (truthConvert(arg) === false) {
      return arg;
    }
  }

  return arg;
}
