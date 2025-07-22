import Component from "@glimmer/component";
import AiSplitTopicSuggester from "../../components/ai-split-topic-suggester";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AiTitleSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }

  <template>
    <AiSplitTopicSuggester
      @selectedPosts={{@outletArgs.selectedPosts}}
      @mode="suggest_title"
      @updateAction={{@outletArgs.updateTopicName}}
    />
  </template>
}
