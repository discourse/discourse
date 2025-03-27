import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import SearchResultEntry from "discourse/components/search-result-entry";

@tagName("")
export default class SearchResultEntries extends Component {
  <template>
    <div class="fps-result-entries" role="list">
      {{#each this.posts as |post|}}
        <SearchResultEntry
          @post={{post}}
          @bulkSelectEnabled={{this.bulkSelectEnabled}}
          @selected={{this.selected}}
          @highlightQuery={{this.highlightQuery}}
          @searchLogId={{this.searchLogId}}
        />
      {{/each}}
    </div>
  </template>
}
