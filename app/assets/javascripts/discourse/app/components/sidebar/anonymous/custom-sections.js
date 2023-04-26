import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Section from "discourse/components/sidebar/user/section";
import SystemSection from "discourse/components/sidebar/common/system-section";

export default class SidebarAnonymousCustomSections extends Component {
  @service router;
  @service site;
  @service siteSettings;

  get sections() {
    return this.site.anonymous_sidebar_sections?.map((section) => {
      const klass = section.system_section ? SystemSection : Section;

      return new klass({
        section,
        currentUser: this.currentUser,
        router: this.router,
        siteSettings: this.siteSettings,
      });
    });
  }
}
