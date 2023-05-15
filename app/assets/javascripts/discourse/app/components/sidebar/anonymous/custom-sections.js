import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SidebarAnonymousCustomSections extends Component {
  @service site;

  get sections() {
    return this.site.anonymous_sidebar_sections;
  }
}
