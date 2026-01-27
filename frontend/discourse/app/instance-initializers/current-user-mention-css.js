import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "hashtag-css-generator",

  initialize() {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();

      if (currentUser) {
        const href = getURL(`/u/${currentUser.username.toLowerCase()}`);
        const style = document.createElement("style");
        style.textContent = `
          a.mention[href="${href}"] {
            background: var(--tertiary-400);
          }
        `;
        document.head.appendChild(style);
      }
    });
  },
};
