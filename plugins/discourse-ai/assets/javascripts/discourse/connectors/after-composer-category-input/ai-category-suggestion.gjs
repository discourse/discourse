import Component from "@glimmer/component";
import { service } from "@ember/service";
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
