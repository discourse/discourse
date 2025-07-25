import Helper from "@ember/component/helper";
import I18n from "discourse-i18n";

export function fullnumber(number) {
  return I18n.toNumber(number, { precision: 0 });
}

export default Helper.helper(fullnumber);
