import Component from "@glimmer/component";
import { service } from "@ember/service";
import AiSearchBestMatch from "../../components/ai-search/ai-search-best-match";

export default class AiSearchBestMatchConnector extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_ask_ai_combined_search_prototype &&
      currentUser?.can_use_ask_ai
    );
  }

  @service aiSearchSession;
  @service search;

  get isBestMatch() {
    if (!this.aiSearchSession.isActiveFor(this.search.activeGlobalSearchTerm)) {
      return false;
    }

    const shownTopicIds = (this.search.results?.posts || []).map(
      (post) => post.topic_id
    );
    return this.aiSearchSession
      .bestMatchIds(shownTopicIds)
      .has(this.args.outletArgs.topic?.id);
  }

  <template>
    {{#if this.isBestMatch}}
      <AiSearchBestMatch />
    {{/if}}
  </template>
}
