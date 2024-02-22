import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ComposerContainer extends Component {
  @service composer;
  @service site;
}
