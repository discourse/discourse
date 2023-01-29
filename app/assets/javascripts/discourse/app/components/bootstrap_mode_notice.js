import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;
  @service site;

  get message() {
    let msg = null;
    const bootstrapModeMinUsers = this.siteSettings.bootstrap_mode_min_users;

    if (bootstrapModeMinUsers > 0) {
      msg = "bootstrap_mode_enabled";
    } else {
      msg = "bootstrap_mode_disabled";
    }

    return htmlSafe(I18n.t(msg, { count: bootstrapModeMinUsers }));
  }

  @action
  inviteUsers() {
    showModal("create-invite");
  }
}
