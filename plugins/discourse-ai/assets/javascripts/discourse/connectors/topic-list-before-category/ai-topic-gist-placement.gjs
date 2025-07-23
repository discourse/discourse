import Component from "@glimmer/component";
import AiTopicGist from "../../components/ai-topic-gist";

export default class AiTopicGistPlacement extends Component {
  static shouldRender(args, context) {
    const settings = context.siteSettings;
    return settings.discourse_ai_enabled && settings.ai_summarization_enabled;
  }

  <template><AiTopicGist @topic={{@outletArgs.topic}} /></template>
}
