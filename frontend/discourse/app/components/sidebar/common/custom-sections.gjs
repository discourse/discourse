import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import CustomSection from "./custom-section";
import CurrentUserService from "discourse/services/current-user";
import SiteService from "discourse/services/site";

export default class SidebarCustomSections extends Component {
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteService) site;

  anonymous = false;

  get sections() {
    if (this.anonymous) {
      return this.site.anonymous_sidebar_sections;
    } else {
      return this.currentUser.sidebarSections;
    }
  }

  <template>
    <div class="sidebar-custom-sections">
      {{#each this.sections as |section|}}
        <CustomSection
          @collapsable={{@collapsable}}
          @enableLinkDrop={{@enableLinkDrop}}
          @expandActiveSection={{@expandActiveSection}}
          @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
          @sectionData={{section}}
          @toggleNavigationMenu={{@toggleNavigationMenu}}
        />
      {{/each}}
    </div>
  </template>
}
