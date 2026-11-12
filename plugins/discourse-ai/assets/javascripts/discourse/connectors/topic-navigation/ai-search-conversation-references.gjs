import Component from "@glimmer/component";
import AiSearchConversationReferences from "../../components/ai-search/ai-search-conversation-references.gjs";
import { combinedSearchActive } from "../../lib/ai-search-scope.js";

// rendered only where the timeline is, which it stands in for
export default class AiSearchConversationReferencesConnector extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      Boolean(args.topic?.ai_search_conversation) &&
      combinedSearchActive(siteSettings, currentUser)
    );
  }

  <template>
    {{#if @outletArgs.renderTimeline}}
      <AiSearchConversationReferences @topic={{@outletArgs.topic}} />
    {{/if}}
  </template>
}
