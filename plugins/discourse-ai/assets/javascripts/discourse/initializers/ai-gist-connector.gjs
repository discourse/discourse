import Component from "@glimmer/component";
import { apiInitializer } from "discourse/lib/api";
import AiTopicGist from "../components/ai-topic-gist";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (
    !siteSettings.discourse_ai_enabled ||
    !siteSettings.ai_summarization_enabled
  ) {
    return;
  }

  const OUTLETS = {
    mobile: "topic-list-before-category",
    desktop: "topic-list-topic-cell-link-bottom-line__before",
  };

  function renderGistInOutlet(outletName, shouldRenderFn) {
    api.renderInOutlet(
      outletName,
      class extends Component {
        static shouldRender(args, context) {
          return shouldRenderFn(context);
        }

        <template><AiTopicGist @topic={{@topic}} /></template>
      }
    );
  }

  renderGistInOutlet(OUTLETS.mobile, (context) => context.site.mobileView);
  renderGistInOutlet(OUTLETS.desktop, (context) => context.site.desktopView);
});
