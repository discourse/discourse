import Component from "@ember/component";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import discourseComputed, { afterRender } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const ACTIONS = ["delete", "delete_replies", "edit", "none"];

export default class AdminPenaltyPostAction extends Component {
  postId = null;
  postAction = null;
  postEdit = null;

  @equal("postAction", "edit") editing;
  @discourseComputed
  penaltyActions() {
    return ACTIONS.map((id) => {
      return { id, name: i18n(`admin.user.penalty_post_${id}`) };
    });
  }

  @action
  penaltyChanged(postAction) {
    this.set("postAction", postAction);

    // If we switch to edit mode, jump to the edit textarea
    if (postAction === "edit") {
      this._focusEditTextarea();
    }
  }

  @afterRender
  _focusEditTextarea() {
    const elem = this.element;
    const body = elem.closest(".d-modal__body");
    body.scrollTo(0, body.clientHeight);
    elem.querySelector(".post-editor").focus();
  }
}
