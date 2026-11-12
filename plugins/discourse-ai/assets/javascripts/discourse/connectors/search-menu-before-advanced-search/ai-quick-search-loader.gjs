import Component from "@glimmer/component";
import { service } from "@ember/service";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default class AiQuickSearchLoader extends Component {
  @service quickSearch;

  <template>
    {{#if this.quickSearch.loading}}
      <div class="ai-quick-search-spinner">
        {{dLoadingSpinner}}
      </div>
    {{/if}}
  </template>
}
