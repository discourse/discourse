import Mixin from "@ember/object/mixin";
import User from "discourse/models/user";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import DismissNewModal from "discourse/components/modal/dismiss-new";

export default Mixin.create({
  modal: service(),

  @action
  resetNew() {
    const user = User.current();
    if (!user.new_new_view_enabled) {
      return this.callResetNew();
    }
    this.modal.show(DismissNewModal, {
      model: {
        dismissTopics: true,
        dismissPosts: true,
        dismissCallback: () =>
          this.callResetNew(
            this.model.dismissPosts,
            this.model.dismissTopics,
            this.model.untrack
          ),
      },
    });
  },
});
