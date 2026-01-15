import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import BulkSelectCheckbox from "discourse/components/topic-list/bulk-select-checkbox";
import TopicExcerpt from "discourse/components/topic-list/topic-excerpt";
import TopicLink from "discourse/components/topic-list/topic-link";
import UnreadIndicator from "discourse/components/topic-list/unread-indicator";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import avatar from "discourse/helpers/avatar";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import number from "discourse/helpers/number";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { shortDateNoYear } from "discourse/lib/formatter";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class HighContextTopicCard extends Component {
  @service capabilities;

  get hasSolved() {
    return (
      this.args.topic.has_accepted_answer || this.args.topic.accepted_answer
    );
  }

  get hasVotes() {
    return this.args.topic.can_vote && this.args.topic.vote_count > 0;
  }

  get voteCountLabel() {
    return i18n(themePrefix("vote_count"), {
      count: this.args.topic.vote_count,
    });
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

  get replyCountLabel() {
    return i18n(themePrefix("reply_count"), {
      count: this.args.topic.replyCount,
    });
  }

  get likeCountLabel() {
    return i18n(themePrefix("like_count"), {
      count: this.args.topic.like_count,
    });
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

  get topicTimestamp() {
    return shortDateNoYear(new Date(this.args.topic.created_at));
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
    <td class="hc-topic-card">
      {{! ROW 1: Creator info + Category + Status }}
      <div class="hc-topic-card__header">
        <div class="hc-topic-card__op">
          <div class="hc-topic-card__avatar">
            {{avatar this.topicCreator imageSize="medium"}}
          </div>
          <div class="hc-topic-card__op-info">
            <span class="hc-topic-card__op-timestamp">
              {{i18n (themePrefix "posted")}}
              {{this.topicTimestamp}}
            </span>
            <span class="hc-topic-card__op-name">
              {{i18n
                (themePrefix "by_username")
                username=this.topicCreator.username
              }}</span>
          </div>

        </div>
        <div class="hc-topic-card__status-tags">
          {{#if this.hasSolved}}
            <span class="hc-topic-card__status --solved">
              {{#if this.capabilities.viewport.sm}}
                {{i18n (themePrefix "solved")}}
              {{/if}}
              {{icon "square-check"}}
            </span>
          {{/if}}

          {{#if this.statusBadge}}
            <span
              class={{concatClass
                "hc-topic-card__status"
                this.statusBadge.className
              }}
            >
              {{icon this.statusBadge.icon}}

              {{#if this.capabilities.viewport.sm}}
                <span class="hc-topic-card__status-text">{{i18n
                    this.statusBadge.text
                  }}</span>
              {{/if}}
            </span>
          {{/if}}
        </div>
      </div>

      {{! ROW 2: Title + Excerpt }}
      <div class="hc-topic-card__content">
        <div class="hc-topic-card__title">
          {{#if @bulkSelectEnabled}}
            <BulkSelectCheckbox
              @topic={{@topic}}
              @isSelected={{@isSelected}}
              @onToggle={{@onBulkSelectToggle}}
              class="hc-topic-card__bulk-select"
            />
          {{/if}}
          <TopicStatus @topic={{@topic}} @context="topic-list" />
          <TopicLink
            {{on "focus" this.onTitleFocus}}
            {{on "blur" this.onTitleBlur}}
            @topic={{@topic}}
            class="hc-topic-card__title raw-link raw-topic-link"
          />
          {{~#if @topic.featured_link~}}
            &nbsp;{{topicFeaturedLink @topic}}
          {{~/if~}}
          <UnreadIndicator @topic={{@topic}} />
          <TopicPostBadges
            @unreadPosts={{@topic.unread_posts}}
            @unseen={{@topic.unseen}}
            @url={{@topic.lastUnreadUrl}}
          />
        </div>

        {{#if this.hasExcerpt}}
          <TopicExcerpt @topic={{@topic}} class="hc-topic-card__excerpt" />
        {{/if}}
      </div>

      {{! ROW 3: Last Reply + Assigned }}

      {{#if (or this.hasReplies this.hasAssigned)}}
        <div class="hc-topic-card__context">
          {{#if this.hasReplies}}
            <div class="hc-topic-card__last-reply">
              {{avatar this.lastPoster.user imageSize="tiny"}}
              <span
                class="hc-topic-card__last-reply-name"
              >{{this.lastPoster.username}}</span>
              <span>{{i18n (themePrefix "replied")}}</span>
              <span class="hc-topic-card__time">
                {{formatDate @topic.bumpedAt leaveAgo="true"}}
              </span>
            </div>
          {{/if}}
          {{#if this.hasAssigned}}
            {{#if this.assignedUser}}
              <div class="hc-topic-card__assigned">
                {{icon "user-plus"}}
                <span
                  class="hc-topic-card__assigned-name"
                >{{this.assignedUser.username}}</span>
              </div>
            {{/if}}
            {{#each this.indirectAssignees as |assignment|}}
              <div class="hc-topic-card__assigned">
                {{icon "user-plus"}}
                <span
                  class="hc-topic-card__assigned-name"
                >{{assignment.user.username}}</span>
                <span
                  class="hc-topic-card__assigned-post"
                >#{{assignment.postNumber}}</span>
              </div>
            {{/each}}
          {{/if}}
        </div>
      {{/if}}

      {{! ROW 4: Stats + Last Reply }}
      <div class="hc-topic-card__footer">
        <div class="hc-topic-card__category-tags">
          {{#unless @hideCategory}}
            <div class="hc-topic-card__category">
              {{categoryLinkHTML @topic.category}}
            </div>
          {{/unless}}

          {{#if this.hasTags}}
            {{discourseTags @topic mode="list" className="hc-topic-card__tags"}}
          {{/if}}
        </div>

        <div class="hc-topic-card__stats">
          {{#if this.hasVotes}}
            <span
              class="hc-topic-card__votes"
              aria-label={{this.voteCountLabel}}
              title={{this.voteCountLabel}}
            >
              {{icon "stamp" skipTitle=true}}
              <span class="hc-topic-card__votes-count">{{number
                  @topic.vote_count
                }}</span>
            </span>
          {{/if}}

          {{#if this.hasReplies}}
            <span
              class="hc-topic-card__replies"
              aria-label={{this.replyCountLabel}}
              title={{this.replyCountLabel}}
            >
              {{icon "reply" skipTitle=true}}
              <span class="hc-topic-card__count">{{number
                  @topic.replyCount
                }}</span>
            </span>
          {{/if}}

          {{#if this.hasLikes}}
            <span
              class="hc-topic-card__likes"
              aria-label={{this.likeCountLabel}}
              title={{this.likeCountLabel}}
            >
              {{icon "heart" skipTitle=true}}
              <span class="hc-topic-card__count">{{number
                  @topic.like_count
                }}</span>
            </span>
          {{/if}}
        </div>
      </div>
    </td>
  </template>
}
