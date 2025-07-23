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
    {{#unless @outletArgs.composer.disableTitleInput}}
      <AiTitleSuggester @composer={{@outletArgs.composer}} @topicState="new" />
    {{/unless}}
  </template>
}
