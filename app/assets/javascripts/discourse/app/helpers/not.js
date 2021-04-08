// https://github.com/jmurphyau/ember-truth-helpers/blob/master/addon/helpers/not.js
import Helper from "@ember/component/helper";
import truthConvert from "discourse/lib/truth-convert";

export function not(params) {
  for (let i = 0, len = params.length; i < len; i++) {
    if (truthConvert(params[i]) === true) {
      return false;
    }
  }
  return true;
}

export default Helper.helper(not);
