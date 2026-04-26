import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "hashtag-css-generator",

  initialize() {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();

      if (currentUser) {
        const href = getURL(`/u/${currentUser.username}`);
        const style = document.createElement("style");
        style.id = "current-user-mention-css";
        style.textContent = `.mention[href="${href}" i] { background: var(--tertiary-400); }`;
        document.head.appendChild(style);
      }
    });
  },
};
