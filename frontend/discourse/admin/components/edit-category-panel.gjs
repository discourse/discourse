/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";

@tagName("")
class EditCategoryPanel extends Component {
  get resolvedComponent() {
    return getOwner(this).resolveRegistration(this.customComponent);
  }

  <template>
    <div
      class={{concatClass
        "edit-category-tab"
        (if this.activeTab "active")
        this.tabClass
      }}
      ...attributes
    >
      <this.resolvedComponent
        @tab={{this.tab}}
        @selectedTab={{this.selectedTab}}
        @category={{this.category}}
      />
    </div>
  </template>
}

/** @returns { any } */
export function buildCategoryPanel(tab) {
  class BuiltCategoryPanel extends EditCategoryPanel {
    @equal("selectedTab", tab) activeTab;
    tabClass = `edit-category-tab-${tab}`;
  }
  return BuiltCategoryPanel;
}
