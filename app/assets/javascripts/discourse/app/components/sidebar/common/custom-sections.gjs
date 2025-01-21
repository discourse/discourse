import Component from "@glimmer/component";
import { service } from "@ember/service";
import CustomSection from "./custom-section";

export default class SidebarCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;
  @service appEvents;
  @service topicTrackingState;
  @service site;
  @service siteSettings;

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
          @sectionData={{section}}
          @collapsable={{@collapsable}}
          @toggleNavigationMenu={{@toggleNavigationMenu}}
        />
      {{/each}}
    </div>
  </template>
}
