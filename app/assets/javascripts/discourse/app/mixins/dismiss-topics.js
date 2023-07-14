import Mixin from "@ember/object/mixin";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import DismissNewModal from "discourse/components/modal/dismiss-new";

export default Mixin.create({
  modal: service(),
  currentUser: service(),

  @action
  resetNew() {
    if (!this.currentUser.new_new_view_enabled) {
      return this.callResetNew();
    }

    this.modal.show(DismissNewModal, {
      model: {
        dismissCallback: ({ dismissPosts, dismissTopics, untrack }) => {
          this.callResetNew(dismissPosts, dismissTopics, untrack);
        },
      },
    });
  },
});
