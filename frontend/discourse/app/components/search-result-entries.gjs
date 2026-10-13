/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import SearchResultEntry from "discourse/components/search-result-entry";

@tagName("")
export default class SearchResultEntries extends Component {
  <template>
    <div class="fps-result-entries" role="list">
      {{#each this.posts as |post|}}
        <SearchResultEntry
          @bulkSelectEnabled={{this.bulkSelectEnabled}}
          @highlightQuery={{this.highlightQuery}}
          @isPMOnly={{this.isPMOnly}}
          @post={{post}}
          @searchLogId={{this.searchLogId}}
          @selected={{this.selected}}
        />
      {{/each}}
    </div>
  </template>
}
