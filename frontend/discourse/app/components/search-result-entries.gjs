import SearchResultEntry from "discourse/components/search-result-entry";

const SearchResultEntries = <template>
  <div class="fps-result-entries" role="list">
    {{#each @posts as |post|}}
      <SearchResultEntry
        @bulkSelectEnabled={{@bulkSelectEnabled}}
        @highlightQuery={{@highlightQuery}}
        @isPMOnly={{@isPMOnly}}
        @post={{post}}
        @searchLogId={{@searchLogId}}
        @selected={{@selected}}
      />
    {{/each}}
  </div>
</template>;

export default SearchResultEntries;
