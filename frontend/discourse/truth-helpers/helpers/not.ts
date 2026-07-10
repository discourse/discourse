import truthConvert, { type MaybeTruthy } from "../utils/truth-convert";

export default function not(...args: MaybeTruthy[]): boolean {
  for (const arg of args) {
    if (truthConvert(arg) === true) {
      return false;
    }
  }

  return true;
}
