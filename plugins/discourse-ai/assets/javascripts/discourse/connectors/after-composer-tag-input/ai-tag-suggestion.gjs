import Component from "@glimmer/component";
import AiTagSuggester from "../../components/suggestion-menus/ai-tag-suggester";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiTagSuggestion extends Component {
  static shouldRender(args, context) {
    return showComposerAiHelper(
      args?.composer,
      context.siteSettings,
      context.currentUser,
      "suggestions"
    );
  }

  <template>
    <AiTagSuggester @composer={{@outletArgs.composer}} @topicState="new" />
  </template>
}
