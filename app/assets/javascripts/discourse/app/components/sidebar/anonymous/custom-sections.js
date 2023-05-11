import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";

export default class SidebarAnonymousCustomSections extends Component {
  @service router;
  @service site;
  @service siteSettings;

  get sections() {
    return this.site.anonymous_sidebar_sections?.map((section) => {
      let klass;
      switch (section.section_type) {
        case "community":
          klass = CommunitySection;
          break;
        default:
          klass = Section;
      }

      return new klass({
        section,
        currentUser: this.currentUser,
        router: this.router,
        siteSettings: this.siteSettings,
      });
    });
  }
}
