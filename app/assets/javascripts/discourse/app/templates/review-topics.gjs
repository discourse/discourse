import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ReviewableClaimedTopic from "discourse/components/reviewable-claimed-topic";
import TopicStatus from "discourse/components/topic-status";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
import replaceEmoji from "discourse/helpers/replace-emoji";
export default RouteTemplate(<template>
  {{#if @controller.reviewableTopics}}
    <table class="reviewable-topics">
      <thead>
        <th>{{iN "review.topics.topic"}} </th>
        <th>{{iN "review.topics.reviewable_count"}}</th>
        <th>{{iN "review.topics.reported_by"}}</th>
        <th></th>
      </thead>
      <tbody>
        {{#each @controller.reviewableTopics as |rt|}}
          <tr class="reviewable-topic">
            <td class="topic-title">
              <div class="combined-title">
                <TopicStatus @topic={{rt}} />
                <a
                  href={{rt.relative_url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{replaceEmoji rt.title}}</a>
              </div>
            </td>
            <td class="reviewable-count">
              {{rt.stats.count}}
            </td>
            <td class="reported-by">
              {{iN "review.topics.unique_users" count=rt.stats.unique_users}}
            </td>
            <td class="reviewable-details">
              <ReviewableClaimedTopic
                @topicId={{rt.id}}
                @claimedBy={{rt.claimed_by}}
                @onClaim={{fn (mut rt.claimed_by)}}
              />
              <LinkTo
                @route="review.index"
                @query={{hash topic_id=rt.id}}
                class="btn btn-primary btn-small"
              >
                {{dIcon "list"}}
                <span>{{iN "review.topics.details"}}</span>
              </LinkTo>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  {{else}}
    <div class="no-review">
      {{iN "review.none"}}
    </div>
  {{/if}}
</template>);
