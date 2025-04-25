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

{{component
  this.customComponent
  tab=this.tab
  selectedTab=this.selectedTab
  category=this.category
}}