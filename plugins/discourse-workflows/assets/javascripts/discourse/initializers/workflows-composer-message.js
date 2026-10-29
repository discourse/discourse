import { withPluginApi } from "discourse/lib/plugin-api";
import { SESSION_ID_FIELD } from "../services/workflows-composer-session.js";

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
    const session = container.lookup("service:workflows-composer-session");

    withPluginApi((api) => api.serializeToDraft(SESSION_ID_FIELD));

    // Before the first autosave, which carries the session to the server.
    appEvents.on("composer:open", ({ model }) => {
      if (model) {
        session.idFor(model);
      }
    });

    container.lookup("service:message-bus").subscribe(
      `/discourse-workflows/composer-message/${currentUser.id}`,
      (data) => {
        const model = composer.model;

        // The user may have posted, closed or switched drafts since pausing,
        // or this may be another tab with the same draft.
        if (
          data?.type !== "show_composer_message" ||
          !model?.viewOpenOrFullscreen ||
          model.draftKey !== data.draft_key ||
          session.idFor(model) !== data.session_id
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
