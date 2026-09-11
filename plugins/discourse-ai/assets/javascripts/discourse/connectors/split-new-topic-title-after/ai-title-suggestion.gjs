import Component from "@glimmer/component";
import AiSplitTopicSuggester from "../../components/ai-split-topic-suggester.gjs";
import { showPostAIHelper } from "../../lib/show-ai-helper.js";

export default class AiTitleSuggestion extends Component {
  static shouldRender(args, context) {
    return showPostAIHelper(args, context);
  }

  <template>
    <AiSplitTopicSuggester
      @mode="suggest_title"
      @selectedPosts={{@outletArgs.selectedPosts}}
      @updateAction={{@outletArgs.updateTopicName}}
    />
  </template>
}
