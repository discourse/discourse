import { apiInitializer } from "discourse/lib/api";
import AiTopicGist from "../components/ai-topic-gist";

export default apiInitializer((api) => {
  const site = api.container.lookup("service:site");
  const settings = api.container.lookup("service:site-settings");

  if (settings.discourse_ai_enabled && settings.ai_summarization_enabled) {
    const gistTemplate = <template>
      <AiTopicGist @topic={{@outletArgs.topic}} />
    </template>;

    const outlet = site.mobileView
      ? "topic-list-before-category"
      : "topic-list-topic-cell-link-bottom-line__before";

    api.renderInOutlet(outlet, gistTemplate);
  }
});
