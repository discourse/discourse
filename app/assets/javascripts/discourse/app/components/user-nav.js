import I18n from "I18n";

import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class UserNav extends Component {
  @service currentUser;
  @service site;
  @service router;

  @tracked
  get draftLabel() {
    const count = this.currentUser.draft_count;

    return count > 0
      ? I18n.t("drafts.label_with_count", { count })
      : I18n.t("drafts.label");
  }
}
