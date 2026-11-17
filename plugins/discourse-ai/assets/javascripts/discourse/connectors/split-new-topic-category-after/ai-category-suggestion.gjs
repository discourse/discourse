import Component from "@glimmer/component";
import { service } from "@ember/service";
import AiSplitTopicSuggester from "../../components/ai-split-topic-suggester.gjs";
import { showPostAIHelper } from "../../lib/show-ai-helper.js";

export default class AiCategorySuggestion extends Component {
  static shouldRender(args, context) {
    return showPostAIHelper(args, context);
  }

  @service siteSettings;

  <template>
    {{#if this.siteSettings.ai_embeddings_enabled}}
      <AiSplitTopicSuggester
        @mode="suggest_category"
        @selectedPosts={{@outletArgs.selectedPosts}}
        @updateAction={{@outletArgs.updateCategoryId}}
      />
    {{/if}}
  </template>
}
