import Component from "@glimmer/component";
import { service } from "@ember/service";
import AiSplitTopicSuggester from "../../components/ai-split-topic-suggester";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AiTagSuggestion extends Component {
  static shouldRender(args, context) {
    return showPostAIHelper(args, context);
  }

  @service siteSettings;

  <template>
    {{#if this.siteSettings.ai_embeddings_enabled}}
      <AiSplitTopicSuggester
        @categoryId={{@outletArgs.categoryId}}
        @currentValue={{@outletArgs.tags}}
        @mode="suggest_tags"
        @selectedPosts={{@outletArgs.selectedPosts}}
        @updateAction={{@outletArgs.updateTags}}
      />
    {{/if}}
  </template>
}
