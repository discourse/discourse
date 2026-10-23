import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerTopicFooterButton } from "discourse/lib/register-topic-footer-button";
import BoardsAddFromTopicMenu from "../components/boards-add-from-topic-menu.gjs";

const BUTTON_ID = "boards-add-from-topic";

export default {
  name: "boards-add-from-topic-button",

  initialize() {
    registerTopicFooterButton({
      id: BUTTON_ID,
      icon: "boards",
      label: "boards.topic_footer.add_to_board",
      title: "boards.topic_footer.add_to_board",
      classNames: ["boards-add-from-topic-button"],
      displayed() {
        if (!this.currentUser) {
          return false;
        }

        if (!this.currentUser.can_edit_any_boards) {
          return false;
        }

        return !this.topic?.isPrivateMessage;
      },
      action() {
        const trigger = document.getElementById(
          `topic-footer-button-${BUTTON_ID}`
        );

        if (!trigger) {
          return;
        }

        getOwner(this)
          .lookup("service:menu")
          .show(trigger, {
            identifier: "discourse-boards-add-from-topic-menu",
            component: BoardsAddFromTopicMenu,
            modalForMobile: true,
            placement: "bottom-start",
            data: { topic: this.topic },
          });
      },
    });

    withPluginApi((api) => {
      api.addTrackedTopicProperties("board_memberships");
    });
  },
};
