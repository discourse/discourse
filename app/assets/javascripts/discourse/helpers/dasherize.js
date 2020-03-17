import Helper from "@ember/component/helper";

function dasherize([value]) {
  return (value || "").replace(".", "-").dasherize();
}

export default Helper.helper(dasherize);
