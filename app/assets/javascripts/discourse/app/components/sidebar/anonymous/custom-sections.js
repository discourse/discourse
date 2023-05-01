import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Section from "discourse/components/sidebar/user/section";
import CommunitySection from "discourse/components/sidebar/common/community-section";

export default class SidebarAnonymousCustomSections extends Component {
  @service router;
  @service site;
  @service siteSettings;

  get sections() {
    return this.site.anonymous_sidebar_sections?.map((section) => {
      const klass = section.section_type ? CommunitySection : Section;

      return new klass({
        section,
        currentUser: this.currentUser,
        router: this.router,
        siteSettings: this.siteSettings,
      });
    });
  }
}
