import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class Blurb extends Component {
  @service siteSettings;
  @service site;
}
