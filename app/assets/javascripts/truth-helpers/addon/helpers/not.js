import truthConvert from "../utils/truth-convert";

export default function not(...args) {
  for (let arg of args) {
    if (truthConvert(arg) === true) {
      return false;
    }
  }

  return true;
}
