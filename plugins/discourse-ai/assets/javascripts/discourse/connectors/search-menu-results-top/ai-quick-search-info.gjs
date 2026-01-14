import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isValidSearchTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class AiQuickSearchInfo extends Component {
  @service search;
  @service siteSettings;
  @service quickSearch;

  get termTooShort() {
    // We check the validity again here because the input may have changed
    // since the last time we checked, so we may want to stop showing the error
    const validity = !isValidSearchTerm(
      this.search.activeGlobalSearchTerm,
      this.siteSettings
    );

    return (
      validity &&
      this.quickSearch.invalidTerm &&
      this.search.activeGlobalSearchTerm?.length > 0
    );
  }

  <template>
    {{#if this.termTooShort}}
      <div class="no-results">{{i18n "search.too_short"}}</div>
    {{/if}}
  </template>
}
