import Helper from "@ember/component/helper";

export function includes(params) {
  return params[0].includes(params[1]);
}

export default Helper.helper(includes);
