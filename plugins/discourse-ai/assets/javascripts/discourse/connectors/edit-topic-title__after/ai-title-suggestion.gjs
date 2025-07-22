import Component from "@glimmer/component";
import AiTitleSuggester from "../../components/suggestion-menus/ai-title-suggester";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiTitleSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAiHelper(
      outletArgs?.composer,
      helper.siteSettings,
      helper.currentUser,
      "suggestions"
    );
  }

  <template>
    <AiTitleSuggester @buffered={{@outletArgs.buffered}} @topicState="edit" />
  </template>
}
