import WorkflowsUserModal from "../components/workflows-user-modal";

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

    messageBus.subscribe(
      channel,
      (data) => {
        if (data?.type === "show_modal") {
          modal.show(WorkflowsUserModal, { model: data });
        }
      },
      lastId
    );
  },
};
