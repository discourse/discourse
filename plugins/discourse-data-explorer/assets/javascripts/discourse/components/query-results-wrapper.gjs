import { i18n } from "discourse-i18n";
import QueryResult from "./query-result";

function formatCachedTime(timestamp) {
  if (!timestamp) {
    return "";
  }
  const seconds = Math.floor(
    (Date.now() - new Date(timestamp).getTime()) / 1000
  );
  if (seconds < 60) {
    return i18n("explorer.cached_just_now");
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return i18n("explorer.cached_minutes_ago", { count: minutes });
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return i18n("explorer.cached_hours_ago", { count: hours });
  }
  const days = Math.floor(hours / 24);
  return i18n("explorer.cached_days_ago", { count: days });
}

const QueryResultsWrapper = <template>
  {{#if @results}}
    <div class="query-results">
      {{#if @showResults}}
        {{#if @cachedAt}}
          <div class="cached-result-notice">
            {{formatCachedTime @cachedAt}}
          </div>
        {{/if}}
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
