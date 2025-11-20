import truthConvert from "../utils/truth-convert";

export default function or(...args) {
  let arg = false;

  for (arg of args) {
    if (truthConvert(arg) === true) {
      return arg;
    }
  }

  return arg;
}
