import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import { i18n } from "discourse-i18n";
import DiscourseReactionsReactionPost from "../components/discourse-reactions-reaction-post";

export default RouteTemplate(
  <template>
    <LoadMore @selector=".user-stream-item" @action={{@controller.loadMore}}>
      <div class="user-stream">
        {{#each @model as |reaction|}}
          <DiscourseReactionsReactionPost @reaction={{reaction}} />
        {{else}}
          <div class="alert alert-info">{{i18n "notifications.empty"}}</div>
        {{/each}}
      </div>

      <ConditionalLoadingSpinner @condition={{@controller.loading}} />
    </LoadMore>
  </template>
);
