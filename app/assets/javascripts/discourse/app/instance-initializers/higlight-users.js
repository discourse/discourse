import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize() {
    withPluginApi("1.37.0", (api) => {
      api.decorateMentions((mentions, user) => {
        const addClass = (selector) => {
          mentions.forEach((mention) => {
            mention.classList.add(selector);
          });
        };

        if (user.id < 0) {
          addClass("--bot");
        } else if (user.id === api.getCurrentUser()?.id) {
          addClass("--current");
        } else if (user.username === "here" || user.username === "all") {
          addClass("--wide");
        }
      });
    });
  },
};
