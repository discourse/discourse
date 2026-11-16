import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import ApiSections from "../api-sections.gjs";
import CategoriesSection from "./categories-section.gjs";
import CustomSections from "./custom-sections.gjs";
import TagsSection from "./tags-section.gjs";

export default class SidebarAnonymousSections extends Component {
  @service sidebarState;
  @service siteSettings;

  get mainPanel() {
    return this.sidebarState.panels.find((panel) => panel.key === MAIN_PANEL);
  }

  <template>
    <div class="sidebar-sections sidebar-sections-anonymous">
      <BlockOutlet @name="sidebar-blocks" />

      <CustomSections
        @collapsable={{@collapsableSections}}
        @expandActiveSection={{this.mainPanel.expandActiveSection}}
        @scrollActiveLinkIntoView={{this.mainPanel.scrollActiveLinkIntoView}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />
      <CategoriesSection
        @collapsable={{@collapsableSections}}
        @expandActiveSection={{this.mainPanel.expandActiveSection}}
        @scrollActiveLinkIntoView={{this.mainPanel.scrollActiveLinkIntoView}}
      />

      {{#if this.siteSettings.tagging_enabled}}
        <TagsSection
          @collapsable={{@collapsableSections}}
          @expandActiveSection={{this.mainPanel.expandActiveSection}}
          @scrollActiveLinkIntoView={{this.mainPanel.scrollActiveLinkIntoView}}
        />
      {{/if}}

      <ApiSections
        @collapsable={{@collapsableSections}}
        @expandActiveSection={{this.mainPanel.expandActiveSection}}
        @scrollActiveLinkIntoView={{this.mainPanel.scrollActiveLinkIntoView}}
      />
    </div>
  </template>
}
