import CategoryChooserComponent from "select-kit/components/category-chooser";

export default CategoryChooserComponent.extend({
  pluginApiIdentifiers: ["search-advanced-category-chooser"],
  classNames: ["search-advanced-category-chooser"],

  selectKitOptions: {
    allowUncategorized: true,
    clearable: true,
    none: "category.all",
    displayCategoryDescription: false,
    permissionType: null
  }
});
