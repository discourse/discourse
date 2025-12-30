import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import TopicExcerpt from "discourse/components/topic-list/topic-excerpt";
import TopicLink from "discourse/components/topic-list/topic-link";
import TopicStatus from "discourse/components/topic-status";
import avatar from "discourse/helpers/avatar";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import number from "discourse/helpers/number";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class DetailedTopicCard extends Component {
  get hasSolved() {
    return (
      this.args.topic.has_accepted_answer || this.args.topic.accepted_answer
    );
  }

  get canHaveAnswer() {
    return this.args.topic.can_have_answer;
  }

  get hasVotes() {
    return this.args.topic.can_vote && this.args.topic.vote_count > 0;
  }

  get voteCount() {
    return this.args.topic.vote_count || 0;
  }

  get hasAssigned() {
    return this.args.topic.assigned_to_user || this.hasIndirectAssignments;
  }

  get assignedUser() {
    return this.args.topic.assigned_to_user;
  }

  get hasIndirectAssignments() {
    const indirect = this.args.topic.indirectly_assigned_to;
    return indirect && Object.keys(indirect).length > 0;
  }

  get indirectAssignees() {
    const indirect = this.args.topic.indirectly_assigned_to;
    if (!indirect) {
      return [];
    }
    return Object.values(indirect).map((assignment) => ({
      user: assignment.assigned_to,
      postNumber: assignment.post_number,
    }));
  }

  get hasTags() {
    return this.args.topic.tags?.length > 0;
  }

  get hasReplies() {
    return this.args.topic.posts_count > 1;
  }

  get hasLikes() {
    return this.args.topic.like_count > 0;
  }

  get hasExcerpt() {
    return this.args.topic.excerpt || this.args.topic.hasExcerpt;
  }

  get statusBadge() {
    if (this.args.topic.is_hot) {
      return {
        icon: "fire",
        text: "topic_statuses.hot.title",
        className: "--hot",
      };
    }
    if (this.args.topic.pinned || this.args.topic.pinned_globally) {
      return {
        icon: "thumbtack",
        text: "topic_statuses.pinned.title",
        className: "--pinned",
      };
    }
    return null;
  }

  get topicCreator() {
    return this.args.topic.creator;
  }

  get lastPoster() {
    return {
      user: this.args.topic.lastPosterUser,
      username: this.args.topic.last_poster_username,
    };
  }

  @action
  onTitleFocus(event) {
    event.target.closest(".topic-list-item").classList.add("selected");
  }

  @action
  onTitleBlur(event) {
    event.target.closest(".topic-list-item").classList.remove("selected");
  }

  <template>
    <td class="detailed-card" colspan="6">
      {{! ROW 1: Creator info + Category + Status }}
      <div class="dc-card__header">
        <div class="dc-card__creator">
          <div class="dc-card__avatar">
            {{avatar this.topicCreator imageSize="medium"}}
          </div>
          <span
            class="dc-card__creator-name"
          >{{this.topicCreator.username}}</span>

          {{#if this.hasSolved}}
            <span class="dc-card__solved">
              {{icon "far-square-check"}}
              {{i18n (themePrefix "solved")}}
            </span>
          {{else if this.canHaveAnswer}}
            <span class="dc-card__unsolved">
              {{icon "far-square"}}
              {{i18n (themePrefix "unsolved")}}
            </span>
          {{/if}}

          {{#if this.hasVotes}}
            <span class="dc-card__votes">
              {{i18n "topic_voting.votes" count=this.voteCount}}
            </span>
          {{/if}}
        </div>

        <div class="dc-card__header-right">
          {{#unless @hideCategory}}
            <div class="dc-card__category">
              {{categoryLinkHTML @topic.category}}
            </div>
          {{/unless}}

          {{#if this.statusBadge}}
            <span
              class={{concatClass "dc-card__status" this.statusBadge.className}}
            >
              {{icon this.statusBadge.icon}}
              <span class="dc-card__status-text">{{i18n
                  this.statusBadge.text
                }}</span>
            </span>
          {{/if}}
        </div>
      </div>

      {{! ROW 2: Title + Excerpt }}
      <div class="dc-card__content">
        <div class="dc-card__title-row">
          <TopicStatus @topic={{@topic}} @context="topic-list" />
          <TopicLink
            {{on "focus" this.onTitleFocus}}
            {{on "blur" this.onTitleBlur}}
            @topic={{@topic}}
            class="dc-card__title raw-link raw-topic-link"
          />
        </div>

        {{#if this.hasExcerpt}}
          <TopicExcerpt @topic={{@topic}} class="dc-card__excerpt" />
        {{/if}}
      </div>

      {{! ROW 3: Assigned + Tags }}
      {{#if (or this.hasAssigned this.hasTags)}}
        <div class="dc-card__context">
          {{#if this.hasAssigned}}
            <div class="dc-card__assignments">
              {{#if this.assignedUser}}
                <div class="dc-card__assigned">
                  {{icon "user-plus"}}
                  {{avatar this.assignedUser imageSize="tiny"}}
                  <span
                    class="dc-card__assigned-name"
                  >{{this.assignedUser.username}}</span>
                </div>
              {{/if}}
              {{#each this.indirectAssignees as |assignment|}}
                <div class="dc-card__assigned dc-card__assigned--indirect">
                  {{icon "user-plus"}}
                  {{avatar assignment.user imageSize="tiny"}}
                  <span
                    class="dc-card__assigned-name"
                  >{{assignment.user.username}}</span>
                  <span
                    class="dc-card__assigned-post"
                  >#{{assignment.postNumber}}</span>
                </div>
              {{/each}}
            </div>
          {{/if}}

          {{#if this.hasTags}}
            <div class="dc-card__tags">
              {{discourseTags @topic mode="list"}}
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{! ROW 4: Stats + Last Reply }}
      <div class="dc-card__footer">
        <div class="dc-card__stats">
          {{#if this.hasReplies}}
            <span class="dc-card__replies">
              {{icon "reply"}}
              <span class="dc-card__count">{{number @topic.posts_count}}</span>
            </span>
          {{/if}}

          {{#if this.hasLikes}}
            <span class="dc-card__likes">
              {{icon "heart"}}
              <span class="dc-card__count">{{number @topic.like_count}}</span>
            </span>
          {{/if}}
        </div>

        <div class="dc-card__last-reply">
          {{avatar this.lastPoster.user imageSize="tiny"}}
          <span
            class="dc-card__last-reply-name"
          >{{this.lastPoster.username}}</span>
          <span class="dc-card__dot-separator"></span>
          <span class="dc-card__time">
            {{formatDate @topic.bumpedAt format="tiny" noTitle="true"}}
          </span>
        </div>
      </div>
    </td>
  </template>
}
