/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { classNameBindings } from "@ember-decorators/component";

export default class EditCategoryPanel extends Component {
  get resolvedComponent() {
    return getOwner(this).resolveRegistration(this.customComponent);
  }

  <template>
    <this.resolvedComponent
      @tab={{this.tab}}
      @selectedTab={{this.selectedTab}}
      @category={{this.category}}
    />
  </template>
}

/** @returns { any } */
export function buildCategoryPanel(tab) {
  @classNameBindings(
    ":edit-category-tab",
    "activeTab:active",
    `:edit-category-tab-${tab}`
  )
  class BuiltCategoryPanel extends EditCategoryPanel {
    @computed("selectedTab")
    get activeTab() {
      return this.selectedTab === tab;
    }
  }
  return BuiltCategoryPanel;
}
