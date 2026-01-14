import Component from "@glimmer/component";
import { service } from "@ember/service";
import loadingSpinner from "discourse/helpers/loading-spinner";

export default class AiQuickSearchLoader extends Component {
  @service quickSearch;

  <template>
    {{#if this.quickSearch.loading}}
      <div class="ai-quick-search-spinner">
        {{loadingSpinner}}
      </div>
    {{/if}}
  </template>
}
