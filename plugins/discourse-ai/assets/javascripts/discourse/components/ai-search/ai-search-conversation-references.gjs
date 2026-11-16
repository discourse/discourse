import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import AiSearchCitedTopics from "../../lib/ai-search-cited-topics.js";
import AiSearchReferencesPanel from "./ai-search-references-panel.gjs";

/** A search conversation's cited topics, standing in for the timeline. */
export default class AiSearchConversationReferences extends Component {
  citedTopics = new AiSearchCitedTopics(getOwner(this), this.args.topic);

  willDestroy() {
    super.willDestroy(...arguments);
    this.citedTopics.teardown();
  }

  <template>
    <AiSearchReferencesPanel @references={{this.citedTopics.references}} />
  </template>
}
