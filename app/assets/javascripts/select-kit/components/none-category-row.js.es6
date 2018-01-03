import CategoryRowComponent from "select-kit/components/category-row";

export default CategoryRowComponent.extend({
  layoutName: "select-kit/templates/components/category-row",
  classNames: "none category-row",

  click() {
    this.sendAction("onClear");
  }
});
