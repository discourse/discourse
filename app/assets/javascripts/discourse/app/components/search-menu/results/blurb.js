import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class Blurb extends Component {
  @service siteSettings;
  @service site;
}
