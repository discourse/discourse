import { next } from "@ember/runloop";
import discourseLater from "discourse/lib/later";
import WorkflowsUserModal from "../components/workflows-user-modal";

// modal.show() only activates a modal once core's keyboard-close wait is
// over (capped at 1s in discourse/lib/wait-for-keyboard), so a close landing
// in that window finds nothing to close and is retried once after the cap.
// Must stay above it.
const CLOSE_RECHECK_MS = 1500;

export default {
  name: "discourse-workflows-user-modal",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");

    if (!currentUser) {
      return;
    }

    const lastId = currentUser.discourse_workflows_user_modal_last_id;

    if (lastId === undefined || lastId === null) {
      return;
    }

    const messageBus = container.lookup("service:message-bus");
    const modal = container.lookup("service:modal");
    const channel = `/discourse-workflows/user-modal/${currentUser.id}`;

    let pendingShow = null;

    const closeIfActive = (modalId) => {
      const active = modal.activeModal;
      if (
        active?.component === WorkflowsUserModal &&
        active.opts?.model?.modal_id === modalId
      ) {
        modal.close();
        return true;
      }
      return false;
    };

    messageBus.subscribe(
      channel,
      (data) => {
        if (data?.type === "show_modal") {
          pendingShow = data;
          // Deferred so that a close_modal delivered in the same poll batch
          // (a tab reconnecting after the modal was handled elsewhere) can
          // cancel the show instead of leaving a stale modal behind.
          next(() => {
            if (pendingShow === data) {
              pendingShow = null;
              modal.show(WorkflowsUserModal, { model: data });
            }
          });
        } else if (data?.type === "close_modal" && data.modal_id) {
          if (pendingShow?.modal_id === data.modal_id) {
            pendingShow = null;
          } else if (!closeIfActive(data.modal_id)) {
            // Safe to fire late — ids are unique per show.
            discourseLater(
              () => closeIfActive(data.modal_id),
              CLOSE_RECHECK_MS
            );
          }
        }
      },
      lastId
    );
  },
};
