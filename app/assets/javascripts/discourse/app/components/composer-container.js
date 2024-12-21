import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class ComposerContainer extends Component {
  @service composer;
  @service site;

  get showPreview() {
    return (
      this.composer.get("showPreview") && this.composer.get("allowPreview")
    );
  }
}
