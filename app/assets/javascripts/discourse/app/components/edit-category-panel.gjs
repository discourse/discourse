<<<<<<< HEAD
{{component
  this.customComponent
  tab=this.tab
  selectedTab=this.selectedTab
  category=this.category
}}
=======
import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import { classNameBindings } from "@ember-decorators/component";

export default class EditCategoryPanel extends Component {}

export function buildCategoryPanel(tab) {
  @classNameBindings(
    ":edit-category-tab",
    "activeTab:active",
    `:edit-category-tab-${tab}`
  )
  class BuiltCategoryPanel extends EditCategoryPanel {
    @equal("selectedTab", tab) activeTab;
  }
  return BuiltCategoryPanel;
}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
