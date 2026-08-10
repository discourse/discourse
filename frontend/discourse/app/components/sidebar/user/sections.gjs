import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import { WEB_LINK_KINDS } from "discourse/lib/sidebar/link-drop";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import ApiSections from "../api-sections";
import CategoriesSection from "./categories-section";
import CustomSections from "./custom-sections";
import TagsSection from "./tags-section";

export default class SidebarUserSections extends Component {
  @service currentUser;

  <template>
    {{! This is the element that scrolls, so a link dragged in from outside can
        only reach a section below the fold if the scrolling happens here. }}
    <div
      class="sidebar-sections"
      {{dDragAndDropAutoScroll accepts=WEB_LINK_KINDS}}
    >
      <BlockOutlet @name="sidebar-blocks" />
      <CustomSections
        @collapsable={{@collapsableSections}}
        @enableLinkDrop={{@enableLinkDrop}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />

      <CategoriesSection
        @collapsable={{@collapsableSections}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />

      {{#if this.currentUser.display_sidebar_tags}}
        <TagsSection @collapsable={{@collapsableSections}} />
      {{/if}}

      {{#unless @hideApiSections}}
        <ApiSections @collapsable={{@collapsableSections}} />
      {{/unless}}
    </div>
  </template>
}
