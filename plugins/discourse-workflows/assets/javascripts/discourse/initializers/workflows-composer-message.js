export default {
  name: "discourse-workflows-composer-message",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const lastId = currentUser?.discourse_workflows_composer_message_last_id;

    if (lastId === undefined || lastId === null) {
      return;
    }

    const composer = container.lookup("service:composer");
    const appEvents = container.lookup("service:app-events");

    container.lookup("service:message-bus").subscribe(
      `/discourse-workflows/composer-message/${currentUser.id}`,
      (data) => {
        const model = composer.model;

        // The user may have posted, closed or switched drafts since pausing.
        if (
          data?.type !== "show_composer_message" ||
          !model?.viewOpenOrFullscreen ||
          model.draftKey !== data.draft_key
        ) {
          return;
        }

        appEvents.trigger("composer-messages:create", {
          extraClass: "workflows-composer-message",
          templateName: "education",
          title: data.title,
          body: data.body,
        });
      },
      lastId
    );
  },
};
