import Helper from "@ember/component/helper";
import { i18n } from "discourse-i18n";

export default Helper.helper(function (params) {
  return i18n(`styleguide.sections.${params[0].replace(/\-/g, "_")}.title`);
});
