import Component from "@glimmer/component";
import { service } from "@ember/service";
import ApiSections from "../api-sections";
import CategoriesSection from "./categories-section";
import CustomSections from "./custom-sections";
import TagsSection from "./tags-section";

export default class SidebarUserSections extends Component {
  @service currentUser;

  <template>
    <div class="sidebar-sections">
      <CustomSections
        @collapsable={{@collapsableSections}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />

      <CategoriesSection @collapsable={{@collapsableSections}} />

      {{#if this.currentUser.display_sidebar_tags}}
        <TagsSection @collapsable={{@collapsableSections}} />
      {{/if}}

      {{#unless @hideApiSections}}
        <ApiSections @collapsable={{@collapsableSections}} />
      {{/unless}}
    </div>
  </template>
}
