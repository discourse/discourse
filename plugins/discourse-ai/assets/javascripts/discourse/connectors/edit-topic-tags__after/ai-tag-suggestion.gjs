import Component from "@glimmer/component";
import AiTagSuggester from "../../components/suggestion-menus/ai-tag-suggester";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiCategorySuggestion extends Component {
  static shouldRender(args, context) {
    return showComposerAiHelper(
      args?.composer,
      context.siteSettings,
      context.currentUser,
      "suggestions"
    );
  }

  <template>
    <AiTagSuggester @buffered={{@outletArgs.buffered}} @topicState="edit" />
  </template>
}
