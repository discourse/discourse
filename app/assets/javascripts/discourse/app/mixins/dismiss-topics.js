import Mixin from "@ember/object/mixin";
import User from "discourse/models/user";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

export default Mixin.create({
  actions: {
    resetNew() {
      const user = User.current();
      if (!user.new_new_view_enabled) {
        return this.callResetNew();
      }
      const controller = showModal("dismiss-new", {
        model: {
          dismissTopics: true,
          dismissPosts: true,
        },
        titleTranslated: I18n.t("topics.bulk.dismiss_new_modal.title"),
      });

      controller.set("dismissCallback", () => {
        this.callResetNew(
          controller.model.dismissPosts,
          controller.model.dismissTopics,
          controller.model.untrack
        );
      });
    },
  },
});
