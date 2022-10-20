import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SidebarFooter extends Component {
  @service capabilities;
  @service site;
  @service siteSettings;
}
