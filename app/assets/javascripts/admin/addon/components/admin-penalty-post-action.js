import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import discourseComputed, {
  afterRender,
} from "discourse-common/utils/decorators";
import I18n from "I18n";

const ACTIONS = ["delete", "delete_replies", "edit", "none"];

export default Component.extend({
  postId: null,
  postAction: null,
  postEdit: null,

  @discourseComputed
  penaltyActions() {
    return ACTIONS.map((id) => {
      return { id, name: I18n.t(`admin.user.penalty_post_${id}`) };
    });
  },

  editing: equal("postAction", "edit"),

  actions: {
    penaltyChanged(postAction) {
      this.set("postAction", postAction);

      // If we switch to edit mode, jump to the edit textarea
      if (postAction === "edit") {
        this._focusEditTextarea();
      }
    },
  },

  @afterRender
  _focusEditTextarea() {
    const elem = this.element;
    const body = elem.closest(".modal-body");
    body.scrollTo(0, body.clientHeight);
    elem.querySelector(".post-editor").focus();
  },
});
