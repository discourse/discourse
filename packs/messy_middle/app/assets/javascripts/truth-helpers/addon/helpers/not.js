import Helper from "@ember/component/helper";
import truthConvert from "../utils/truth-convert";

export function not(params) {
  for (let i = 0, len = params.length; i < len; i++) {
    if (truthConvert(params[i]) === true) {
      return false;
    }
  }
  return true;
}

export default Helper.helper(not);
