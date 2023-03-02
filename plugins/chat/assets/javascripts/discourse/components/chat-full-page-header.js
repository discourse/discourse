import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class ChatFullPageHeader extends Component {
  @service site;
  @service chatStateManager;

  get displayed() {
    return this.args.displayed ?? true;
  }
}
