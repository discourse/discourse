import QueryResult from "./query-result";

const QueryResultsWrapper = <template>
  {{#if @results}}
    <div class="query-results">
      {{#if @showResults}}
        <QueryResult @query={{@query}} @content={{@results}} />
      {{else}}
        {{#each @results.errors as |err|}}
          <pre class="query-error"><code>{{~err}}</code></pre>
        {{/each}}
      {{/if}}
    </div>
  {{/if}}
</template>;

export default QueryResultsWrapper;
