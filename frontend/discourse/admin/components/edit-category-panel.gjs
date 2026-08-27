/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNameBindings } from "@ember-decorators/component";

/** @returns { any } */
export function buildCategoryPanel(tab) {
  @classNameBindings(
    ":edit-category-tab",
    "activeTab:active",
    `:edit-category-tab-${tab}`
  )
  class BuiltCategoryPanel extends Component {
    @computed("selectedTab")
    get activeTab() {
      return this.selectedTab === tab;
    }
  }
  return BuiltCategoryPanel;
}
