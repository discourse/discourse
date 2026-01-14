import { classNames } from "@ember-decorators/component";
import CategoryChooserComponent from "discourse/select-kit/components/category-chooser";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";

@classNames("search-advanced-category-chooser")
@selectKitOptions({
  allowUncategorized: true,
  clearable: true,
  none: "category.all",
  displayCategoryDescription: false,
  permissionType: null,
})
@pluginApiIdentifiers("search-advanced-category-chooser")
export default class SearchAdvancedCategoryChooser extends CategoryChooserComponent {}
