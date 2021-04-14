import Helper from "@ember/component/helper";

export function notEqualHelper(params) {
  return params[0] !== params[1];
}

export default Helper.helper(notEqualHelper);
