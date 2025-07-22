import Component from "@glimmer/component";
import AiTagSuggester from "../../components/suggestion-menus/ai-tag-suggester";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiCategorySuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAiHelper(
      outletArgs?.composer,
      helper.siteSettings,
      helper.currentUser,
      "suggestions"
    );
  }

  <template>
    <AiTagSuggester @buffered={{@outletArgs.buffered}} @topicState="edit" />
  </template>
}
