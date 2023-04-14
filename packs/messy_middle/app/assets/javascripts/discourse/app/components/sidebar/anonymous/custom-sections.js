import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Section from "discourse/components/sidebar/user/section";

export default class SidebarAnonymousCustomSections extends Component {
  @service router;
  @service site;

  get sections() {
    return this.site.anonymous_sidebar_sections?.map((section) => {
      return new Section({
        section,
        router: this.router,
      });
    });
  }
}
