import Component from "@glimmer/component";
import AiTitleSuggester from "../../components/suggestion-menus/ai-title-suggester";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiTitleSuggestion extends Component {
  static shouldRender(args, context) {
    return showComposerAiHelper(
      args?.composer,
      context.siteSettings,
      context.currentUser,
      "suggestions"
    );
  }

  <template>
    <AiTitleSuggester @buffered={{@outletArgs.buffered}} @topicState="edit" />
  </template>
}
