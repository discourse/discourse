import { withPluginApi } from "discourse/lib/plugin-api";
import { incrementTopicsOpened } from "../connectors/topic-above-footer-buttons/patreon";

function initWithApi(api) {
  const currentUser = api.getCurrentUser();

  api.onAppEvent("page:topic-loaded", (topic) => {
    if (!topic) {
      return;
    }

    const isPrivateMessage = topic.isPrivateMessage;

    if (!currentUser || isPrivateMessage) {
      return;
    }

    incrementTopicsOpened();
  });
}

export default {
  name: "patreon",
  initialize() {
    withPluginApi("0.8", initWithApi);
  },
};
