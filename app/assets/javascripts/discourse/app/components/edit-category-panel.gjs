import Component from "@ember/component";
import { equal } from "@ember/object/computed";
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
