import Component from "@glimmer/component";
import AiTopicGist from "../../components/ai-topic-gist";

export default class AiTopicGistPlacement extends Component {
  static shouldRender(_outletArgs, helper) {
    const settings = helper.siteSettings;
    return settings.discourse_ai_enabled && settings.ai_summarization_enabled;
  }

  <template><AiTopicGist @topic={{@outletArgs.topic}} /></template>
}
