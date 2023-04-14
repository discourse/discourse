import Helper from "@ember/component/helper";
import { dasherize as emberDasherize } from "@ember/string";

function dasherize([value]) {
  return emberDasherize((value || "").replace(".", "-"));
}

export default Helper.helper(dasherize);
