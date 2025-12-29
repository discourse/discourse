import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "../lib/math-renderer";

function initializeMath(api, discourseMathOptions) {
  api.decorateCookedElement(
    (element) => {
      next(() => {
        renderMathInElement(element, discourseMathOptions);
      });
    },
    { id: "mathjax" }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => {
        renderMathInElement(element, discourseMathOptions);
      },
      {
        id: "mathjax-chat",
      }
    );
  }
}

export default {
  name: "apply-math-mathjax",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const discourseMathOptions = buildDiscourseMathOptions(siteSettings);
    if (
      discourseMathOptions.enabled &&
      discourseMathOptions.provider === "mathjax"
    ) {
      withPluginApi(function (api) {
        initializeMath(api, discourseMathOptions);
      });
    }
  },
};
