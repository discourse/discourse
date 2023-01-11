import Helper from "@ember/component/helper";
import I18n from "I18n";

export default Helper.helper(function (params) {
  return I18n.t(`styleguide.sections.${params[0].replace(/\-/g, "_")}.title`);
});
