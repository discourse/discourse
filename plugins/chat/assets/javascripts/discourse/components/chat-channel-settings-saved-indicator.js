import discourseLater from "discourse-common/lib/later";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";

const ACTIVE_DURATION = 2000;

export default class ChatChannelSettingsSavedIndicator extends Component {
  @tracked isActive = false;
  property = null;

  @action
  activate() {
    cancel(this._deactivateHandler);

    this.isActive = true;

    this._deactivateHandler = discourseLater(() => {
      this.isActive = false;
    }, ACTIVE_DURATION);
  }

  @action
  teardown() {
    cancel(this._deactivateHandler);
  }
}
