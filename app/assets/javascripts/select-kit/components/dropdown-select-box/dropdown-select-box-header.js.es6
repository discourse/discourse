import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import discourseComputed from "discourse-common/utils/decorators";

export default SelectKitHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/dropdown-select-box/dropdown-select-box-header",
  classNames: "btn-default dropdown-select-box-header",
  tagName: "button",

  classNameBindings: ["btnClassName"],

  @discourseComputed("options.showFullTitle")
  btnClassName(showFullTitle) {
    return `btn ${showFullTitle ? "btn-icon-text" : "no-text btn-icon"}`;
  }
});
