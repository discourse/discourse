import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize() {
    withPluginApi("1.36.0", (api) => {
      const username = api.getCurrentUser()?.username;
      if (!username) {
        return;
      }

      const style = document.createElement("style");
      style.type = "text/css";
      const cssRule = `.inline-onebox[data-author="${username}"] { background: var(--tertiary-400); }`;
      style.appendChild(document.createTextNode(cssRule));

      document.head.appendChild(style);
    });
  },
};
