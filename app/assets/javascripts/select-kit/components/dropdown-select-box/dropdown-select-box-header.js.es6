import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import computed from "ember-addons/ember-computed-decorators";

export default SelectKitHeaderComponent.extend({
  layoutName:
    "select-kit/templates/components/dropdown-select-box/dropdown-select-box-header",
  classNames: "dropdown-select-box-header",
  tagName: "button",

  classNameBindings: ["btnClassName"],

  @computed("options.showFullTitle")
  btnClassName(showFullTitle) {
    return `btn ${showFullTitle ? "btn-icon-text" : "no-text btn-icon"}`;
  }
});
