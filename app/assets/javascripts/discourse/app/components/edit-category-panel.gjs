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
<<<<<<< HEAD
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
=======
>>>>>>> e41897a306 (DEV: [gjs-codemod] Convert final core components/routes to gjs)
