import Component from "@glimmer/component";
import { service } from "@ember/service";
import AiCategorySuggester from "../../components/suggestion-menus/ai-category-suggester";
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

  @service composer;

  <template>
    {{#unless this.composer.disableCategoryChooser}}
      <AiCategorySuggester
        @composer={{@outletArgs.composer}}
        @topicState="new"
      />
    {{/unless}}
  </template>
}
