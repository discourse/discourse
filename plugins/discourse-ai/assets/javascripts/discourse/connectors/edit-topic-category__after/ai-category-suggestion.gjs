import Component from "@glimmer/component";
import AiCategorySuggester from "../../components/suggestion-menus/ai-category-suggester";
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
    <AiCategorySuggester
      @buffered={{@outletArgs.buffered}}
      @topicState="edit"
    />
  </template>
}
